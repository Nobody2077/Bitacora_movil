package com.jcyq.bitacorarpg

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Programa y cancela las alarmas de recordatorio.
 *
 * Vive fuera de [MissionNotificationBridge] porque el receiver de arranque
 * tambien tiene que reprogramar, y alli no hay Activity: solo el contexto de
 * aplicacion. Se usa `setAndAllowWhileIdle` a proposito; las alarmas exactas
 * quedaron descartadas por consumo de bateria.
 */
internal object MissionAlarmScheduler {
    fun schedule(
        context: Context,
        scheduleId: String,
        systemNotificationId: Int,
        notifyAtUtcMs: Long,
        soundEnabled: Boolean,
        showDetails: Boolean,
        missionTitle: String?,
    ) {
        val appContext = context.applicationContext
        val alarmManager =
            appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val triggerAt = maxOf(notifyAtUtcMs, System.currentTimeMillis() + 1_000L)
        val pendingIntent = alarmPendingIntent(
            context = appContext,
            scheduleId = scheduleId,
            systemNotificationId = systemNotificationId,
            soundEnabled = soundEnabled,
            showDetails = showDetails,
            missionTitle = missionTitle,
            flags = PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                triggerAt,
                pendingIntent,
            )
        } else {
            alarmManager.set(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
        }
    }

    fun cancel(context: Context, systemNotificationId: Int) {
        val appContext = context.applicationContext
        val alarmManager =
            appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        PendingIntent.getBroadcast(
            appContext,
            systemNotificationId,
            Intent(appContext, MissionAlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )?.let(alarmManager::cancel)
        MissionAlarmReceiver.cancel(appContext, systemNotificationId)
    }

    fun stableSystemId(scheduleId: String): Int {
        val value = scheduleId.hashCode() and Int.MAX_VALUE
        return if (value == 0) 1 else value
    }

    private fun alarmPendingIntent(
        context: Context,
        scheduleId: String,
        systemNotificationId: Int,
        soundEnabled: Boolean,
        showDetails: Boolean,
        missionTitle: String?,
        flags: Int,
    ): PendingIntent {
        val intent = Intent(context, MissionAlarmReceiver::class.java).apply {
            putExtra(MissionAlarmReceiver.EXTRA_SCHEDULE_ID, scheduleId)
            putExtra(MissionAlarmReceiver.EXTRA_SYSTEM_ID, systemNotificationId)
            putExtra(MissionAlarmReceiver.EXTRA_SOUND_ENABLED, soundEnabled)
            putExtra(MissionAlarmReceiver.EXTRA_SHOW_DETAILS, showDetails)
            missionTitle?.let {
                putExtra(MissionAlarmReceiver.EXTRA_MISSION_TITLE, it)
            }
        }
        return PendingIntent.getBroadcast(
            context,
            systemNotificationId,
            intent,
            flags or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
