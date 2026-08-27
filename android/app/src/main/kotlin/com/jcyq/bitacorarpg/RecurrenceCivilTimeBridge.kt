package com.jcyq.bitacorarpg

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.time.LocalDate
import java.time.LocalTime
import java.time.ZoneId

/** Conversions for recurrence civil dates using Android's IANA time-zone DB. */
internal class RecurrenceCivilTimeBridge : MethodChannel.MethodCallHandler {
    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/recurrence_civil_time"
        const val INVALID_ARGUMENT = "INVALID_ARGUMENT"
    }

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "currentTimeZoneId" -> result.success(ZoneId.systemDefault().id)
                "localDateForUtc" -> {
                    val utcEpochMillis = call.argument<Number>("utcEpochMillis")?.toLong()
                        ?: throw IllegalArgumentException("utcEpochMillis is required")
                    val zone = zone(call)
                    result.success(
                        Instant.ofEpochMilli(utcEpochMillis).atZone(zone).toLocalDate().toString(),
                    )
                }
                "localDateTimeToUtcEpochMillis" -> {
                    val localDate = call.argument<String>("localDate")
                        ?: throw IllegalArgumentException("localDate is required")
                    val minutes = call.argument<Number>("localTimeMinutes")?.toInt()
                        ?: throw IllegalArgumentException("localTimeMinutes is required")
                    require(minutes in 0..1439) { "localTimeMinutes is out of range" }
                    val localDateTime = LocalDate.parse(localDate).atTime(
                        LocalTime.of(minutes / 60, minutes % 60),
                    )
                    result.success(localDateTime.atZone(zone(call)).toInstant().toEpochMilli())
                }
                else -> result.notImplemented()
            }
        } catch (error: RuntimeException) {
            result.error(INVALID_ARGUMENT, error.message, null)
        }
    }

    private fun zone(call: MethodCall): ZoneId {
        val timeZoneId = call.argument<String>("timeZoneId")
            ?: throw IllegalArgumentException("timeZoneId is required")
        return ZoneId.of(timeZoneId)
    }
}
