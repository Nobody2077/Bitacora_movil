package com.jcyq.bitacorarpg

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel

internal class DeviceBatteryBridge(context: Context) : EventChannel.StreamHandler {
    private val appContext = context.applicationContext
    private var receiver: BroadcastReceiver? = null
    private var eventSink: EventChannel.EventSink? = null

    fun register(messenger: BinaryMessenger) {
        EventChannel(messenger, CHANNEL).setStreamHandler(this)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        val batteryReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    emitLevel(intent)
                }
            }
        receiver = batteryReceiver
        val filter = IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        val stickyIntent =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                appContext.registerReceiver(
                    batteryReceiver,
                    filter,
                    Context.RECEIVER_EXPORTED,
                )
            } else {
                @Suppress("DEPRECATION")
                appContext.registerReceiver(batteryReceiver, filter)
            }
        emitLevel(stickyIntent)
    }

    override fun onCancel(arguments: Any?) {
        receiver?.let {
            try {
                appContext.unregisterReceiver(it)
            } catch (_: IllegalArgumentException) {
                // El receptor ya no estaba registrado.
            }
        }
        receiver = null
        eventSink = null
    }

    private fun emitLevel(intent: Intent?) {
        if (intent == null) return
        val level = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        if (level < 0 || scale <= 0) {
            eventSink?.success(null)
            return
        }
        val percentage = ((level * 100f) / scale).toInt().coerceIn(0, 100)
        eventSink?.success(percentage)
    }

    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/device_battery"
    }
}
