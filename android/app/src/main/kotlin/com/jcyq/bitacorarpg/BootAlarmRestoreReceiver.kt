package com.jcyq.bitacorarpg

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Repone las alarmas despues de un reinicio del telefono o de una
 * actualizacion de la aplicacion, que es cuando Android las borra todas.
 *
 * Este receiver NUNCA abre la base cifrada: lee el espejo de [BootAlarmMirror]
 * y nada mas. Por eso las notificaciones que repone salen siempre con texto
 * generico, aunque el usuario tenga activado "mostrar detalles": ni el titulo
 * de la mision ni el recuento del resumen viven en el espejo, y no hay forma de
 * recuperarlos sin el PIN. Cuando el usuario abre la aplicacion, `reconcile()`
 * las reprograma completas.
 */
class BootAlarmRestoreReceiver : BroadcastReceiver() {
    private companion object {
        const val SUMMARY_FALLBACK = "Abre Bitácora para ver tu resumen de hoy."
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED
        ) {
            return
        }

        val appContext = context.applicationContext
        val entries = BootAlarmMirror.readAll(appContext)
        if (entries.isEmpty()) return

        val now = System.currentTimeMillis()
        for (entry in entries) {
            try {
                // El resumen diario no puede decir cuantas misiones hay: ese
                // recuento se precocina con la app desbloqueada y no viaja al
                // espejo. Se invita a abrir la aplicacion, sin dar cifras.
                val fallbackText =
                    if (entry.kind == BootAlarmMirror.KIND_DAILY_SUMMARY) {
                        SUMMARY_FALLBACK
                    } else {
                        null
                    }
                if (entry.notifyAtUtcMs <= now) {
                    // Vencio mientras el telefono estaba apagado. Se entrega ya;
                    // el propio receiver descarta duplicados por scheduleId.
                    MissionAlarmReceiver.deliver(
                        context = appContext,
                        scheduleId = entry.scheduleId,
                        systemNotificationId = entry.systemNotificationId,
                        soundEnabled = entry.soundEnabled,
                        showDetails = entry.showDetails,
                        missionTitle = null,
                        contentText = fallbackText,
                    )
                } else {
                    MissionAlarmScheduler.schedule(
                        context = appContext,
                        scheduleId = entry.scheduleId,
                        systemNotificationId = entry.systemNotificationId,
                        notifyAtUtcMs = entry.notifyAtUtcMs,
                        soundEnabled = entry.soundEnabled,
                        showDetails = entry.showDetails,
                        missionTitle = null,
                        contentText = fallbackText,
                    )
                }
            } catch (_: Exception) {
                // Una alarma que no se puede reponer no debe impedir las demas.
                continue
            }
        }
    }
}
