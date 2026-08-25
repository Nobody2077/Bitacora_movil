package com.jcyq.bitacorarpg

import android.content.Context
import android.content.pm.ApplicationInfo
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Persists the opaque A2 access-state JSON separately from the database key.
 *
 * The initialized marker is deliberately stored alongside, but outside, the encrypted blob. Any
 * partial combination of marker, blob, and Android Keystore alias is treated as a fail-closed
 * state. Only debug builds can address `test_*` stores or invoke destructive test operations.
 */
internal class AccessCredentialStoreBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {
    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/access_credential_store"
        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val INITIALIZED_MARKER = "initialized"
        const val WRAPPED_ACCESS_STATE = "wrapped_access_state"
        const val MATERIAL_VERSION = "v1"
        const val PRIMARY_STORAGE_ID = "primary"
        const val MAX_PAYLOAD_BYTES = 65_536
        const val GCM_TAG_BITS = 128
        const val GCM_IV_BYTES = 12
        const val GENERIC_ERROR_MESSAGE = "Access state is unavailable."
        val TEST_STORAGE_ID_PATTERN = Regex("test_[a-z0-9_]{1,27}")
    }

    private val isDebuggable: Boolean
        get() = context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE != 0

    fun register(messenger: BinaryMessenger) {
        MethodChannel(
            messenger,
            CHANNEL,
            StandardMethodCodec.INSTANCE,
            messenger.makeBackgroundTaskQueue(),
        ).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "readAccessState" -> result.success(
                    readAccessState(
                        databaseExists = requiredBoolean(call, "databaseExists"),
                        storageId = validatedStorageId(requiredString(call, "storageId")),
                    ),
                )

                "writeAccessState" -> {
                    writeAccessState(
                        storageId = validatedStorageId(requiredString(call, "storageId")),
                        payload = requiredString(call, "payload"),
                    )
                    result.success(null)
                }

                "clearTestMaterial" -> {
                    clearTestMaterial(
                        validatedStorageId(requiredString(call, "storageId")),
                    )
                    result.success(null)
                }

                "corruptTestMaterial" -> {
                    corruptTestMaterial(
                        storageId = validatedStorageId(requiredString(call, "storageId")),
                        mode = optionalString(call, "mode") ?: "blob",
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (failure: AccessStoreFailure) {
            result.error(failure.code, GENERIC_ERROR_MESSAGE, null)
        } catch (_: Exception) {
            result.error("ACCESS_FAILURE", GENERIC_ERROR_MESSAGE, null)
        }
    }

    @Synchronized
    private fun readAccessState(
        databaseExists: Boolean,
        storageId: String,
    ): String? {
        val snapshot = materialSnapshot(storageId)
        if (snapshot.isClean) {
            if (databaseExists) {
                throw AccessStoreFailure("ACCESS_STATE_MISSING_FOR_EXISTING_DATABASE")
            }
            return null
        }

        val blob = snapshot.requireReadableBlob()
        val plaintext = unwrap(blob, storageId)
        try {
            validatePayloadBytes(plaintext)
            return plaintext.toString(Charsets.UTF_8)
        } finally {
            plaintext.fill(0)
        }
    }

    @Synchronized
    private fun writeAccessState(
        storageId: String,
        payload: String,
    ) {
        val payloadBytes = payload.toByteArray(Charsets.UTF_8)
        try {
            validatePayloadBytes(payloadBytes)

            val before = materialSnapshot(storageId)
            val wrappingKey = if (before.isClean) {
                createWrappingKey(storageId)
            } else {
                val previousPlaintext = unwrap(before.requireReadableBlob(), storageId)
                previousPlaintext.fill(0)
                existingWrappingKey(storageId)
            }

            val encoded = wrap(payloadBytes, wrappingKey)
            val persisted = preferences(storageId)
                .edit()
                .putBoolean(INITIALIZED_MARKER, true)
                .putString(WRAPPED_ACCESS_STATE, encoded)
                .commit()
            if (!persisted) {
                throw AccessStoreFailure("ACCESS_STATE_PERSISTENCE_FAILED")
            }

            val after = materialSnapshot(storageId)
            val verified = unwrap(after.requireReadableBlob(), storageId)
            try {
                if (!payloadBytes.contentEquals(verified)) {
                    throw AccessStoreFailure("ACCESS_STATE_VERIFICATION_FAILED")
                }
            } finally {
                verified.fill(0)
            }
        } finally {
            payloadBytes.fill(0)
        }
    }

    private fun wrap(plaintext: ByteArray, wrappingKey: SecretKey): String {
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
            val ciphertext = cipher.doFinal(plaintext)
            val iv = cipher.iv
            try {
                if (iv.size != GCM_IV_BYTES) {
                    throw AccessStoreFailure("ACCESS_ENCRYPTION_FAILED")
                }
                return listOf(
                    MATERIAL_VERSION,
                    Base64.encodeToString(iv, Base64.NO_WRAP),
                    Base64.encodeToString(ciphertext, Base64.NO_WRAP),
                ).joinToString(":")
            } finally {
                iv.fill(0)
                ciphertext.fill(0)
            }
        } catch (failure: AccessStoreFailure) {
            throw failure
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_ENCRYPTION_FAILED")
        }
    }

    private fun unwrap(encodedMaterial: String, storageId: String): ByteArray {
        val pieces = encodedMaterial.split(":")
        if (pieces.size != 3 || pieces[0] != MATERIAL_VERSION) {
            throw AccessStoreFailure("ACCESS_STATE_INVALID")
        }

        val iv = decodeBase64(pieces[1])
        val ciphertext = decodeBase64(pieces[2])
        try {
            if (iv.size != GCM_IV_BYTES || ciphertext.size <= GCM_TAG_BITS / 8) {
                throw AccessStoreFailure("ACCESS_STATE_INVALID")
            }

            return try {
                val cipher = Cipher.getInstance("AES/GCM/NoPadding")
                cipher.init(
                    Cipher.DECRYPT_MODE,
                    existingWrappingKey(storageId),
                    GCMParameterSpec(GCM_TAG_BITS, iv),
                )
                cipher.doFinal(ciphertext)
            } catch (failure: AccessStoreFailure) {
                throw failure
            } catch (_: Exception) {
                throw AccessStoreFailure("ACCESS_STATE_UNREADABLE")
            }
        } finally {
            iv.fill(0)
            ciphertext.fill(0)
        }
    }

    private fun createWrappingKey(storageId: String): SecretKey {
        val keyStore = loadKeyStore()
        if (keyStore.containsAlias(alias(storageId))) {
            throw AccessStoreFailure("ACCESS_STATE_INCONSISTENT")
        }

        return try {
            val generator = KeyGenerator.getInstance(
                KeyProperties.KEY_ALGORITHM_AES,
                KEYSTORE_PROVIDER,
            )
            generator.init(
                KeyGenParameterSpec.Builder(
                    alias(storageId),
                    KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
                )
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true)
                    .build(),
            )
            generator.generateKey()
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_KEYSTORE_FAILURE")
        }
    }

    private fun existingWrappingKey(storageId: String): SecretKey {
        return try {
            loadKeyStore().getKey(alias(storageId), null) as? SecretKey
                ?: throw AccessStoreFailure("ACCESS_WRAPPING_KEY_MISSING")
        } catch (failure: AccessStoreFailure) {
            throw failure
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_KEYSTORE_FAILURE")
        }
    }

    private fun materialSnapshot(storageId: String): MaterialSnapshot {
        val values = try {
            preferences(storageId).all
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_STATE_INCONSISTENT")
        }

        val aliasPresent = try {
            loadKeyStore().containsAlias(alias(storageId))
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_KEYSTORE_FAILURE")
        }

        return MaterialSnapshot(
            hasMarker = values.containsKey(INITIALIZED_MARKER),
            initialized = values[INITIALIZED_MARKER] as? Boolean,
            hasBlob = values.containsKey(WRAPPED_ACCESS_STATE),
            blob = values[WRAPPED_ACCESS_STATE] as? String,
            aliasPresent = aliasPresent,
        )
    }

    private fun loadKeyStore(): KeyStore = try {
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }
    } catch (_: Exception) {
        throw AccessStoreFailure("ACCESS_KEYSTORE_FAILURE")
    }

    private fun preferences(storageId: String) = context.getSharedPreferences(
        "access_credential_store_v1_$storageId",
        Context.MODE_PRIVATE,
    )

    private fun alias(storageId: String) =
        "com.jcyq.bitacorarpg.access_state_wrap_v1.$storageId"

    private fun validatedStorageId(storageId: String): String {
        if (storageId == PRIMARY_STORAGE_ID) {
            return storageId
        }
        if (!TEST_STORAGE_ID_PATTERN.matches(storageId)) {
            throw AccessStoreFailure("ACCESS_INVALID_STORAGE_ID")
        }
        if (!isDebuggable) {
            throw AccessStoreFailure("ACCESS_STORAGE_NOT_ALLOWED")
        }
        return storageId
    }

    @Synchronized
    private fun clearTestMaterial(storageId: String) {
        requireTestOperation(storageId)
        if (!preferences(storageId).edit().clear().commit()) {
            throw AccessStoreFailure("ACCESS_TEST_CLEANUP_FAILED")
        }

        try {
            val keyStore = loadKeyStore()
            if (keyStore.containsAlias(alias(storageId))) {
                keyStore.deleteEntry(alias(storageId))
            }
        } catch (failure: AccessStoreFailure) {
            throw failure
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_TEST_CLEANUP_FAILED")
        }
    }

    @Synchronized
    private fun corruptTestMaterial(storageId: String, mode: String) {
        requireTestOperation(storageId)
        val snapshot = materialSnapshot(storageId)
        snapshot.requireReadableBlob()

        when (mode) {
            "blob" -> {
                if (!preferences(storageId)
                        .edit()
                        .putString(WRAPPED_ACCESS_STATE, "$MATERIAL_VERSION:AA==:AA==")
                        .commit()
                ) {
                    throw AccessStoreFailure("ACCESS_TEST_CORRUPTION_FAILED")
                }
            }

            "alias" -> {
                try {
                    val keyStore = loadKeyStore()
                    if (!keyStore.containsAlias(alias(storageId))) {
                        throw AccessStoreFailure("ACCESS_TEST_STATE_REQUIRED")
                    }
                    keyStore.deleteEntry(alias(storageId))
                } catch (failure: AccessStoreFailure) {
                    throw failure
                } catch (_: Exception) {
                    throw AccessStoreFailure("ACCESS_TEST_CORRUPTION_FAILED")
                }
            }

            else -> throw AccessStoreFailure("ACCESS_INVALID_CORRUPTION_MODE")
        }
    }

    private fun requireTestOperation(storageId: String) {
        if (!isDebuggable || !TEST_STORAGE_ID_PATTERN.matches(storageId)) {
            throw AccessStoreFailure("ACCESS_TEST_OPERATION_NOT_ALLOWED")
        }
    }

    private fun validatePayloadBytes(payload: ByteArray) {
        if (payload.isEmpty() || payload.size > MAX_PAYLOAD_BYTES) {
            throw AccessStoreFailure("ACCESS_INVALID_PAYLOAD")
        }
    }

    private fun decodeBase64(value: String): ByteArray = try {
        Base64.decode(value, Base64.NO_WRAP)
    } catch (_: IllegalArgumentException) {
        throw AccessStoreFailure("ACCESS_STATE_INVALID")
    }

    private fun requiredString(call: MethodCall, name: String): String =
        try {
            call.argument<String>(name) ?: throw AccessStoreFailure("ACCESS_INVALID_ARGUMENT")
        } catch (failure: AccessStoreFailure) {
            throw failure
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_INVALID_ARGUMENT")
        }

    private fun optionalString(call: MethodCall, name: String): String? =
        try {
            call.argument<String>(name)
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_INVALID_ARGUMENT")
        }

    private fun requiredBoolean(call: MethodCall, name: String): Boolean =
        try {
            call.argument<Boolean>(name) ?: throw AccessStoreFailure("ACCESS_INVALID_ARGUMENT")
        } catch (failure: AccessStoreFailure) {
            throw failure
        } catch (_: Exception) {
            throw AccessStoreFailure("ACCESS_INVALID_ARGUMENT")
        }

    private data class MaterialSnapshot(
        val hasMarker: Boolean,
        val initialized: Boolean?,
        val hasBlob: Boolean,
        val blob: String?,
        val aliasPresent: Boolean,
    ) {
        val isClean: Boolean
            get() = !hasMarker && !hasBlob && !aliasPresent

        fun requireReadableBlob(): String {
            if (!hasMarker || initialized != true || !hasBlob || blob == null) {
                throw AccessStoreFailure("ACCESS_STATE_INCONSISTENT")
            }
            if (!aliasPresent) {
                throw AccessStoreFailure("ACCESS_WRAPPING_KEY_MISSING")
            }
            return blob
        }
    }

    private class AccessStoreFailure(val code: String) : Exception(code)
}
