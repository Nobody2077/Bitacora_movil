package com.jcyq.bitacorarpg

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    private lateinit var missionNotificationBridge: MissionNotificationBridge

    override fun onCreate(savedInstanceState: Bundle?) {
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DatabaseKeyStoreBridge(applicationContext).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        AccessCredentialStoreBridge(applicationContext).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        PrivacyWindowBridge(this).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        RecurrenceCivilTimeBridge().register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        DeviceBatteryBridge(applicationContext).register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
        missionNotificationBridge = MissionNotificationBridge(this)
        missionNotificationBridge.register(
            flutterEngine.dartExecutor.binaryMessenger,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        if (::missionNotificationBridge.isInitialized &&
            missionNotificationBridge.handlePermissionResult(requestCode, grantResults)
        ) {
            return
        }
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    }
}
