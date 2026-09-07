package com.jcyq.bitacorarpg

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Espejo minimo y cifrado de las alarmas pendientes, guardado FUERA de la base.
 *
 * Existe porque Android borra todas las alarmas de AlarmManager al reiniciar el
 * telefono, y el receiver de arranque no puede abrir la base cifrada: por
 * ADR-002 sigue cerrada hasta que el usuario introduce su PIN. Sin este espejo
 * no queda nada que reponer.
 *
 * Decision del usuario del 7 de septiembre de 2026 (Opcion A). Los terminos son
 * vinculantes y no se amplian sin volver a preguntar:
 *
 * - Solo scheduleId, systemNotificationId, notifyAtUtcMs, soundEnabled y
 *   showDetails.
 * - NUNCA el titulo de la mision ni ningun otro contenido de la base.
 * - Cifrado con una clave de AndroidKeyStore que no exige autenticacion de
 *   usuario, para poder leerse al arrancar.
 *
 * Se sigue el mismo formato `v1:iv:ciphertext` que [DatabaseKeyStoreBridge]
 * para no introducir una segunda forma de cifrar en el proyecto.
 */
internal object BootAlarmMirror {
    private const val PREFERENCES = "boot_alarm_mirror_v1"
    private const val PAYLOAD = "payload"
    private const val MATERIAL_VERSION = "v1"
    private const val KEYSTORE_PROVIDER = "AndroidKeyStore"
    private const val KEY_ALIAS = "com.jcyq.bitacorarpg.boot_alarm_mirror_v1"
    private const val GCM_TAG_BITS = 128
    private const val MIRROR_VERSION = 1

    data class Entry(
        val scheduleId: String,
        val systemNotificationId: Int,
        val notifyAtUtcMs: Long,
        val soundEnabled: Boolean,
        val showDetails: Boolean,
    )

    /**
     * Reemplaza el espejo completo. `reconcile()` conoce el conjunto entero de
     * alarmas vivas, asi que sustituir es correcto y evita que queden restos de
     * alarmas ya canceladas.
     */
    @Synchronized
    fun replaceAll(context: Context, entries: List<Entry>) {
        val preferences = preferences(context)
        if (entries.isEmpty()) {
            preferences.edit().remove(PAYLOAD).apply()
            return
        }
        val array = JSONArray()
        for (entry in entries) {
            array.put(
                JSONObject().apply {
                    put("scheduleId", entry.scheduleId)
                    put("systemNotificationId", entry.systemNotificationId)
                    put("notifyAtUtcMs", entry.notifyAtUtcMs)
                    put("soundEnabled", entry.soundEnabled)
                    put("showDetails", entry.showDetails)
                },
            )
        }
        val document = JSONObject().apply {
            put("version", MIRROR_VERSION)
            put("entries", array)
        }
        preferences.edit()
            .putString(PAYLOAD, encrypt(document.toString()))
            .apply()
    }

    /**
     * Devuelve el espejo, o vacio si no hay nada legible. Nunca lanza: al
     * arrancar, un espejo ilegible debe degradar a "no repongo alarmas", jamas
     * tumbar el receiver.
     */
    @Synchronized
    fun readAll(context: Context): List<Entry> = try {
        val payload = preferences(context).getString(PAYLOAD, null)
        if (payload == null) {
            emptyList()
        } else {
            parse(decrypt(payload))
        }
    } catch (_: Exception) {
        emptyList()
    }

    @Synchronized
    fun clear(context: Context) {
        preferences(context).edit().remove(PAYLOAD).apply()
    }

    private fun parse(document: String): List<Entry> {
        val root = JSONObject(document)
        if (root.optInt("version", 0) != MIRROR_VERSION) return emptyList()
        val array = root.optJSONArray("entries") ?: return emptyList()
        val entries = ArrayList<Entry>(array.length())
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val scheduleId = item.optString("scheduleId")
            val systemNotificationId = item.optInt("systemNotificationId")
            if (scheduleId.isBlank() || systemNotificationId <= 0) continue
            entries.add(
                Entry(
                    scheduleId = scheduleId,
                    systemNotificationId = systemNotificationId,
                    notifyAtUtcMs = item.optLong("notifyAtUtcMs"),
                    soundEnabled = item.optBoolean("soundEnabled", true),
                    showDetails = item.optBoolean("showDetails", false),
                ),
            )
        }
        return entries
    }

    private fun encrypt(plaintext: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, getOrCreateKey())
        val ciphertext = cipher.doFinal(plaintext.toByteArray(Charsets.UTF_8))
        return listOf(
            MATERIAL_VERSION,
            Base64.encodeToString(cipher.iv, Base64.NO_WRAP),
            Base64.encodeToString(ciphertext, Base64.NO_WRAP),
        ).joinToString(":")
    }

    private fun decrypt(material: String): String {
        val pieces = material.split(":")
        require(pieces.size == 3 && pieces[0] == MATERIAL_VERSION)
        val key = loadKeyStore().getKey(KEY_ALIAS, null) as? SecretKey
            ?: throw IllegalStateException("Mirror key is missing.")
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(
            Cipher.DECRYPT_MODE,
            key,
            GCMParameterSpec(GCM_TAG_BITS, Base64.decode(pieces[1], Base64.NO_WRAP)),
        )
        return String(
            cipher.doFinal(Base64.decode(pieces[2], Base64.NO_WRAP)),
            Charsets.UTF_8,
        )
    }

    private fun getOrCreateKey(): SecretKey {
        val keyStore = loadKeyStore()
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            KEYSTORE_PROVIDER,
        )
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .setRandomizedEncryptionRequired(true)
                // Sin setUserAuthenticationRequired: el receiver de arranque
                // tiene que poder descifrar antes de que el usuario abra la app.
                .build(),
        )
        return generator.generateKey()
    }

    private fun loadKeyStore(): KeyStore =
        KeyStore.getInstance(KEYSTORE_PROVIDER).apply { load(null) }

    private fun preferences(context: Context) =
        context.applicationContext.getSharedPreferences(
            PREFERENCES,
            Context.MODE_PRIVATE,
        )
}
