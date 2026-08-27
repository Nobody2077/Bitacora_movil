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
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal class DatabaseKeyStoreBridge(private val context: Context) :
    MethodChannel.MethodCallHandler {
    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/database_key_store"
        const val KEYSTORE_PROVIDER = "AndroidKeyStore"
        const val WRAPPED_MATERIAL = "wrapped_material"
        const val MATERIAL_VERSION = "v1"
        const val PRIMARY_STORAGE_ID = "primary"
        const val JOURNAL_ATTACHMENTS_STORAGE_ID = "journal_attachments"
        const val DATABASE_KEY_BYTES = 32
        const val GCM_TAG_BITS = 128
        val STORAGE_ID_PATTERN = Regex("[a-z0-9_]{1,32}")
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
                "getOrCreateDatabaseKey" -> result.success(
                    getOrCreateDatabaseKey(
                        databaseExists = call.argument<Boolean>("databaseExists")
                            ?: throw KeyStoreFailure("INVALID_ARGUMENT"),
                        storageId = validatedStorageId(
                            call.argument<String>("storageId") ?: PRIMARY_STORAGE_ID,
                        ),
                    ),
                )

                "clearTestMaterial" -> {
                    clearTestMaterial(
                        validatedStorageId(
                            call.argument<String>("storageId")
                                ?: throw KeyStoreFailure("INVALID_ARGUMENT"),
                        ),
                    )
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        } catch (failure: KeyStoreFailure) {
            result.error(failure.code, "Database key is unavailable.", null)
        } catch (_: Exception) {
            result.error("KEYSTORE_FAILURE", "Database key is unavailable.", null)
        }
    }

    @Synchronized
    private fun getOrCreateDatabaseKey(
        databaseExists: Boolean,
        storageId: String,
    ): String {
        val preferences = preferences(storageId)
        val encodedMaterial = preferences.getString(WRAPPED_MATERIAL, null)

        if (encodedMaterial != null) {
            val databaseKey = unwrap(encodedMaterial, storageId)
            try {
                return databaseKey.useAsHex()
            } finally {
                databaseKey.fill(0)
            }
        }

        if (databaseExists) {
            throw KeyStoreFailure("KEY_MISSING_FOR_EXISTING_DATABASE")
        }

        val wrappingKey = getOrCreateWrappingKey(storageId)
        val databaseKey = ByteArray(DATABASE_KEY_BYTES)
        SecureRandom().nextBytes(databaseKey)

        try {
            val encoded = wrap(databaseKey, wrappingKey)
            if (!preferences.edit().putString(WRAPPED_MATERIAL, encoded).commit()) {
                throw KeyStoreFailure("KEY_PERSISTENCE_FAILED")
            }

            val verified = unwrap(
                preferences.getString(WRAPPED_MATERIAL, null)
                    ?: throw KeyStoreFailure("KEY_PERSISTENCE_FAILED"),
                storageId,
            )
            try {
                if (!databaseKey.contentEquals(verified)) {
                    throw KeyStoreFailure("KEY_VERIFICATION_FAILED")
                }
            } finally {
                verified.fill(0)
            }

            return databaseKey.useAsHex()
        } finally {
            databaseKey.fill(0)
        }
    }

    private fun wrap(databaseKey: ByteArray, wrappingKey: SecretKey): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, wrappingKey)
        val ciphertext = cipher.doFinal(databaseKey)
        return listOf(
            MATERIAL_VERSION,
            Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
            Base64.encodeToString(ciphertext, Base64.NO_WRAP),
        ).joinToString(":")
    }

    private fun unwrap(encodedMaterial: String, storageId: String): ByteArray {
        val pieces = encodedMaterial.split(":")
        if (pieces.size != 3 || pieces[0] != MATERIAL_VERSION) {
            throw KeyStoreFailure("KEY_MATERIAL_INVALID")
        }

        val keyStore = loadKeyStore()
        val wrappingKey = keyStore.getKey(alias(storageId), null) as? SecretKey
            ?: throw KeyStoreFailure("WRAPPING_KEY_MISSING")
        val iv = decodeBase64(pieces[1])
        val ciphertext = decodeBase64(pieces[2])

        val plaintext = try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(
                Cipher.DECRYPT_MODE,
                wrappingKey,
                GCMParameterSpec(GCM_TAG_BITS, iv),
            )
            cipher.doFinal(ciphertext)
        } catch (_: Exception) {
            throw KeyStoreFailure("KEY_MATERIAL_UNREADABLE")
        } finally {
            iv.fill(0)
            ciphertext.fill(0)
        }

        if (plaintext.size != DATABASE_KEY_BYTES) {
            plaintext.fill(0)
            throw KeyStoreFailure("KEY_LENGTH_INVALID")
        }
        return plaintext
    }

    private fun getOrCreateWrappingKey(storageId: String): SecretKey {
        val keyStore = loadKeyStore()
        (keyStore.getKey(alias(storageId), null) as? SecretKey)?.let { return it }

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
        return generator.generateKey()
    }

    private fun loadKeyStore(): KeyStore = KeyStore.getInstance(KEYSTORE_PROVIDER).apply {
        load(null)
    }

    private fun preferences(storageId: String) = context.getSharedPreferences(
        "database_key_store_v1_$storageId",
        Context.MODE_PRIVATE,
    )

    private fun alias(storageId: String) =
        "com.jcyq.bitacorarpg.database_wrap_v1.$storageId"

    private fun validatedStorageId(storageId: String): String {
        if (!STORAGE_ID_PATTERN.matches(storageId)) {
            throw KeyStoreFailure("INVALID_STORAGE_ID")
        }
        if (
            storageId != PRIMARY_STORAGE_ID &&
            storageId != JOURNAL_ATTACHMENTS_STORAGE_ID &&
            !isDebuggable
        ) {
            throw KeyStoreFailure("TEST_STORAGE_NOT_ALLOWED")
        }
        return storageId
    }

    @Synchronized
    private fun clearTestMaterial(storageId: String) {
        if (!isDebuggable || !storageId.startsWith("test_")) {
            throw KeyStoreFailure("TEST_OPERATION_NOT_ALLOWED")
        }

        if (!preferences(storageId).edit().clear().commit()) {
            throw KeyStoreFailure("TEST_CLEANUP_FAILED")
        }
        val keyStore = loadKeyStore()
        if (keyStore.containsAlias(alias(storageId))) {
            keyStore.deleteEntry(alias(storageId))
        }
    }

    private fun decodeBase64(value: String): ByteArray = try {
        Base64.decode(value, Base64.NO_WRAP)
    } catch (_: IllegalArgumentException) {
        throw KeyStoreFailure("KEY_MATERIAL_INVALID")
    }

    private fun ByteArray.useAsHex(): String = joinToString(separator = "") { byte ->
        (byte.toInt() and 0xff).toString(16).padStart(2, '0')
    }

    private class KeyStoreFailure(val code: String) : Exception(code)
}
