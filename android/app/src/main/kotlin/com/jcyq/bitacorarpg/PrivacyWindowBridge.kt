package com.jcyq.bitacorarpg

import android.app.Activity
import android.view.WindowManager
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Read-only runtime evidence for the A2 Android privacy contract. */
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

            "usesFragmentActivity" -> result.success(
                activity is io.flutter.embedding.android.FlutterFragmentActivity,
            )

            else -> result.notImplemented()
        }
    }
}
