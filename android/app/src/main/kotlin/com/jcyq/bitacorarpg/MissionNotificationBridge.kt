package com.jcyq.bitacorarpg

import android.Manifest
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
            "syncBootMirror" -> syncBootMirror(call, result)
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
            MissionAlarmScheduler.schedule(
                context = activity.applicationContext,
                scheduleId = request.scheduleId,
                systemNotificationId = request.systemNotificationId,
                notifyAtUtcMs = request.notifyAtUtcMs,
                soundEnabled = request.soundEnabled,
                showDetails = request.showDetails,
                missionTitle = request.missionTitle,
                contentText = request.contentText,
            )
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
                contentText = request.contentText,
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
        MissionAlarmScheduler.cancel(activity.applicationContext, systemId)
        result.success(null)
    }

    /**
     * Reemplaza el espejo de arranque con las alarmas vivas.
     *
     * Dart manda el conjunto completo tras cada `reconcile()`. Aqui se descarta
     * cualquier campo que no sean los cinco acordados: el titulo de la mision
     * no debe llegar nunca al espejo, asi que ni siquiera se lee.
     */
    private fun syncBootMirror(call: MethodCall, result: MethodChannel.Result) {
        val raw = call.argument<List<Map<String, Any?>>>("entries")
        if (raw == null) {
            result.error("INVALID_MIRROR", "entries is required.", null)
            return
        }
        val entries = raw.mapNotNull { item ->
            val scheduleId = (item["scheduleId"] as? String)?.takeIf { it.isNotBlank() }
                ?: return@mapNotNull null
            val systemNotificationId = (item["systemNotificationId"] as? Number)?.toInt()
                ?.takeIf { it > 0 }
                ?: return@mapNotNull null
            val notifyAtUtcMs = (item["notifyAtUtcMs"] as? Number)?.toLong()
                ?: return@mapNotNull null
            BootAlarmMirror.Entry(
                scheduleId = scheduleId,
                systemNotificationId = systemNotificationId,
                notifyAtUtcMs = notifyAtUtcMs,
                soundEnabled = item["soundEnabled"] as? Boolean ?: true,
                showDetails = item["showDetails"] as? Boolean ?: false,
                kind = (item["kind"] as? String)?.takeIf { it.isNotBlank() }
                    ?: BootAlarmMirror.KIND_MISSION,
            )
        }
        BootAlarmMirror.replaceAll(activity.applicationContext, entries)
        result.success(entries.size)
    }

    private fun requestFrom(call: MethodCall): AlarmRequest {
        val scheduleId = call.argument<String>("scheduleId")
            ?.takeIf { it.isNotBlank() }
            ?: throw IllegalArgumentException("scheduleId is required.")
        val notifyAtUtcMs = call.argument<Number>("notifyAtUtcMs")?.toLong()
            ?: throw IllegalArgumentException("notifyAtUtcMs is required.")
        val existingSystemId = call.argument<Int>("systemNotificationId")
        val systemId = existingSystemId?.takeIf { it > 0 }
            ?: MissionAlarmScheduler.stableSystemId(scheduleId)
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
            contentText = call.argument<String>("contentText")
                ?.trim()
                ?.take(160)
                ?.takeIf { it.isNotEmpty() },
        )
    }

    private data class AlarmRequest(
        val scheduleId: String,
        val notifyAtUtcMs: Long,
        val systemNotificationId: Int,
        val soundEnabled: Boolean,
        val showDetails: Boolean,
        val missionTitle: String?,
        val contentText: String?,
    )
}
