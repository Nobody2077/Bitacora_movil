package com.jcyq.bitacorarpg

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat

class MissionAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_SCHEDULE_ID = "schedule_id"
        const val EXTRA_SYSTEM_ID = "system_notification_id"
        const val EXTRA_SOUND_ENABLED = "sound_enabled"
        const val EXTRA_SHOW_DETAILS = "show_details"
        const val EXTRA_MISSION_TITLE = "mission_title"
        const val EXTRA_CONTENT_TEXT = "content_text"

        private const val CHANNEL_SOUND = "mission_reminders"
        private const val CHANNEL_SILENT = "mission_reminders_silent"
        private const val CHANNEL_SOUND_DETAILS = "mission_reminders_details"
        private const val CHANNEL_SILENT_DETAILS = "mission_reminders_silent_details"
        private const val DELIVERED_PREFERENCES = "mission_notifications_delivered"

        fun deliver(
            context: Context,
            scheduleId: String,
            systemNotificationId: Int,
            soundEnabled: Boolean,
            showDetails: Boolean,
            missionTitle: String?,
            contentText: String? = null,
        ) {
            if (scheduleId.isBlank() || systemNotificationId <= 0) return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                ContextCompat.checkSelfPermission(
                    context,
                    Manifest.permission.POST_NOTIFICATIONS,
                ) != PackageManager.PERMISSION_GRANTED
            ) return

            val preferences = context.getSharedPreferences(
                DELIVERED_PREFERENCES,
                Context.MODE_PRIVATE,
            )
            if (preferences.getBoolean(scheduleId, false)) return

            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val detailsVisible = showDetails && !missionTitle.isNullOrBlank()
            val channelId = when {
                detailsVisible && soundEnabled -> CHANNEL_SOUND_DETAILS
                detailsVisible -> CHANNEL_SILENT_DETAILS
                soundEnabled -> CHANNEL_SOUND
                else -> CHANNEL_SILENT
            }
            ensureChannel(manager, channelId, soundEnabled, detailsVisible)
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val contentIntent = PendingIntent.getActivity(
                context,
                systemNotificationId,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Notification.Builder(context, channelId)
            } else {
                @Suppress("DEPRECATION")
                Notification.Builder(context)
            }
            val notification = builder
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(context.getString(R.string.app_name))
                .setContentText(
                    when {
                        !contentText.isNullOrBlank() -> contentText
                        detailsVisible -> missionTitle
                        else -> "Tienes una misión programada."
                    },
                )
                .setVisibility(
                    if (detailsVisible) {
                        Notification.VISIBILITY_PUBLIC
                    } else {
                        Notification.VISIBILITY_PRIVATE
                    },
                )
                .setCategory(Notification.CATEGORY_REMINDER)
                .setAutoCancel(true)
                .setContentIntent(contentIntent)
                .build()
            manager.notify(systemNotificationId, notification)
            preferences.edit().putBoolean(scheduleId, true).apply()
        }

        fun cancel(context: Context, systemNotificationId: Int) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(systemNotificationId)
        }

        private fun ensureChannel(
            manager: NotificationManager,
            channelId: String,
            soundEnabled: Boolean,
            detailsVisible: Boolean,
        ) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                manager.getNotificationChannel(channelId) != null
            ) return
            val name = if (soundEnabled) "Recordatorios de misiones" else "Recordatorios silenciosos"
            val channel = NotificationChannel(
                channelId,
                name,
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = if (detailsVisible) {
                    "Avisos de misiones con título visible"
                } else {
                    "Avisos privados de misiones programadas"
                }
                lockscreenVisibility = if (detailsVisible) {
                    Notification.VISIBILITY_PUBLIC
                } else {
                    Notification.VISIBILITY_PRIVATE
                }
                if (!soundEnabled) {
                    setSound(null, null)
                    enableVibration(false)
                }
            }
            manager.createNotificationChannel(channel)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        deliver(
            context = context.applicationContext,
            scheduleId = intent.getStringExtra(EXTRA_SCHEDULE_ID).orEmpty(),
            systemNotificationId = intent.getIntExtra(EXTRA_SYSTEM_ID, 0),
            soundEnabled = intent.getBooleanExtra(EXTRA_SOUND_ENABLED, true),
            showDetails = intent.getBooleanExtra(EXTRA_SHOW_DETAILS, false),
            missionTitle = intent.getStringExtra(EXTRA_MISSION_TITLE),
            contentText = intent.getStringExtra(EXTRA_CONTENT_TEXT),
        )
    }
}
