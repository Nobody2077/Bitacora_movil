package com.jcyq.bitacorarpg

import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.Context
import android.os.Build
import android.os.PersistableBundle
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Portapapeles para el código de recuperación.
 *
 * Marca el contenido como sensible (Android 13+), así el sistema no lo muestra
 * en la vista previa y los teclados que respetan la marca no lo guardan en su
 * historial. `clearIfMatches` solo borra si el portapapeles aún contiene ese
 * mismo texto: nunca pisa algo que el usuario copió después.
 */
internal class SensitiveClipboardBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val clipboard = context.applicationContext.getSystemService(ClipboardManager::class.java)

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val manager = clipboard
        if (manager == null) {
            result.error("UNAVAILABLE", "Clipboard service unavailable", null)
            return
        }
        when (call.method) {
            "copySensitive" -> {
                val text = call.argument<String>("text")
                if (text.isNullOrEmpty()) {
                    result.error("INVALID_ARGUMENT", "Missing text", null)
                    return
                }
                val clip = ClipData.newPlainText("", text)
                clip.description.extras = PersistableBundle().apply {
                    putBoolean(sensitiveExtraKey(), true)
                }
                manager.setPrimaryClip(clip)
                result.success(null)
            }
            "clearIfMatches" -> {
                val text = call.argument<String>("text")
                val current = manager.primaryClip
                    ?.takeIf { it.itemCount > 0 }
                    ?.getItemAt(0)
                    ?.text
                    ?.toString()
                if (text.isNullOrEmpty() || current != text) {
                    result.success(false)
                    return
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    manager.clearPrimaryClip()
                } else {
                    manager.setPrimaryClip(ClipData.newPlainText("", ""))
                }
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    private fun sensitiveExtraKey(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ClipDescription.EXTRA_IS_SENSITIVE
        } else {
            LEGACY_SENSITIVE_EXTRA
        }

    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/sensitive_clipboard"
        const val LEGACY_SENSITIVE_EXTRA = "android.content.extra.IS_SENSITIVE"
    }
}
