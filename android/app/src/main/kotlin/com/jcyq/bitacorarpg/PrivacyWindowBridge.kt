package com.jcyq.bitacorarpg

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Runtime control and evidence for the Android screenshot privacy contract. */
internal class PrivacyWindowBridge(private val activity: Activity) :
    MethodChannel.MethodCallHandler {
    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/privacy_window"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isFlagSecureEnabled" -> {
                val flags = activity.window.attributes.flags
                result.success(flags and WindowManager.LayoutParams.FLAG_SECURE != 0)
            }

            "setFlagSecureEnabled" -> {
                val enabled = call.argument<Boolean>("enabled")
                if (enabled == null) {
                    result.error("INVALID_ARGUMENT", "enabled is required.", null)
                    return
                }
                activity.runOnUiThread {
                    if (enabled) {
                        activity.window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        activity.window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(null)
                }
            }

            "usesFragmentActivity" -> result.success(
                activity is io.flutter.embedding.android.FlutterFragmentActivity,
            )

            else -> result.notImplemented()
        }
    }
}
