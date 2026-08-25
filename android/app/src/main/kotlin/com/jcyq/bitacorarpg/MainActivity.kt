package com.jcyq.bitacorarpg

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
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
    }
}
