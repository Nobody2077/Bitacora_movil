package com.jcyq.bitacorarpg

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MissionNotificationBridge(
    private val activity: FlutterFragmentActivity,
) {
    companion object {
        private const val CHANNEL = "com.jcyq.bitacorarpg/mission_notifications"
        private const val PERMISSION_REQUEST = 46031
    }

    private var permissionResult: MethodChannel.Result? = null

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(::onMethodCall)
    }

    fun handlePermissionResult(
        requestCode: Int,
        grantResults: IntArray,
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST) return false
        val granted = grantResults.isNotEmpty() &&
            grantResults[0] == PackageManager.PERMISSION_GRANTED
        permissionResult?.success(granted)
        permissionResult = null
        return true
    }

    private fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestPermission" -> requestPermission(result)
            "schedule" -> schedule(call, result)
            "deliverIfNeeded" -> deliverIfNeeded(call, result)
            "cancel" -> cancel(call, result)
            else -> result.notImplemented()
        }
    }

    private fun requestPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        if (permissionResult != null) {
            result.error(
                "PERMISSION_REQUEST_ACTIVE",
                "A notification permission request is already active.",
                null,
            )
            return
        }
        permissionResult = result
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            PERMISSION_REQUEST,
        )
    }

    private fun schedule(call: MethodCall, result: MethodChannel.Result) {
        try {
            val request = requestFrom(call)
            val alarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val triggerAt = maxOf(request.notifyAtUtcMs, System.currentTimeMillis() + 1_000L)
            val pendingIntent = alarmPendingIntent(request, PendingIntent.FLAG_UPDATE_CURRENT)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent,
                )
            } else {
                alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
            result.success(request.systemNotificationId)
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_NOTIFICATION", error.message, null)
        } catch (error: SecurityException) {
            result.error("NOTIFICATION_SECURITY", error.message, null)
        }
    }

    private fun deliverIfNeeded(call: MethodCall, result: MethodChannel.Result) {
        try {
            val request = requestFrom(call)
            MissionAlarmReceiver.deliver(
                context = activity.applicationContext,
                scheduleId = request.scheduleId,
                systemNotificationId = request.systemNotificationId,
                soundEnabled = request.soundEnabled,
                showDetails = request.showDetails,
                missionTitle = request.missionTitle,
            )
            result.success(request.systemNotificationId)
        } catch (error: IllegalArgumentException) {
            result.error("INVALID_NOTIFICATION", error.message, null)
        }
    }

    private fun cancel(call: MethodCall, result: MethodChannel.Result) {
        val systemId = call.argument<Int>("systemNotificationId")
        if (systemId == null || systemId <= 0) {
            result.error("INVALID_NOTIFICATION_ID", "A positive notification id is required.", null)
            return
        }
        val alarmManager = activity.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        PendingIntent.getBroadcast(
            activity,
            systemId,
            Intent(activity, MissionAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )?.let(alarmManager::cancel)
        MissionAlarmReceiver.cancel(activity.applicationContext, systemId)
        result.success(null)
    }

    private fun requestFrom(call: MethodCall): AlarmRequest {
        val scheduleId = call.argument<String>("scheduleId")
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("scheduleId is required.")
        val notifyAtUtcMs = call.argument<Number>("notifyAtUtcMs")?.toLong()
            ?: throw IllegalArgumentException("notifyAtUtcMs is required.")
        val existingSystemId = call.argument<Int>("systemNotificationId")
        val systemId = existingSystemId?.takeIf { it > 0 } ?: stableSystemId(scheduleId)
        return AlarmRequest(
            scheduleId = scheduleId,
            notifyAtUtcMs = notifyAtUtcMs,
            systemNotificationId = systemId,
            soundEnabled = call.argument<Boolean>("soundEnabled") ?: true,
            showDetails = call.argument<Boolean>("showDetails") ?: false,
            missionTitle = call.argument<String>("missionTitle")
                ?.trim()
                ?.take(120)
                ?.takeIf { it.isNotEmpty() },
        )
    }

    private fun alarmPendingIntent(request: AlarmRequest, flags: Int): PendingIntent {
        val intent = Intent(activity, MissionAlarmReceiver::class.java).apply {
            putExtra(MissionAlarmReceiver.EXTRA_SCHEDULE_ID, request.scheduleId)
            putExtra(MissionAlarmReceiver.EXTRA_SYSTEM_ID, request.systemNotificationId)
            putExtra(MissionAlarmReceiver.EXTRA_SOUND_ENABLED, request.soundEnabled)
            putExtra(MissionAlarmReceiver.EXTRA_SHOW_DETAILS, request.showDetails)
            request.missionTitle?.let {
                putExtra(MissionAlarmReceiver.EXTRA_MISSION_TITLE, it)
            }
        }
        return PendingIntent.getBroadcast(
            activity,
            request.systemNotificationId,
            intent,
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stableSystemId(scheduleId: String): Int {
        val value = scheduleId.hashCode() and Int.MAX_VALUE
        return if (value == 0) 1 else value
    }

    private data class AlarmRequest(
        val scheduleId: String,
        val notifyAtUtcMs: Long,
        val systemNotificationId: Int,
        val soundEnabled: Boolean,
        val showDetails: Boolean,
        val missionTitle: String?,
    )
}
