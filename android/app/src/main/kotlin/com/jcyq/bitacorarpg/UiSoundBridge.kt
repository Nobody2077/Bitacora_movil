package com.jcyq.bitacorarpg

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.SoundPool
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Efectos breves de interfaz con SoundPool.
 *
 * Nunca solicita foco de audio: la música u otro audio del usuario sigue
 * sonando sin pausa ni atenuación. Con el teléfono en silencio o vibración no
 * reproduce nada. Qué efectos están activos lo decide Dart; aquí solo se
 * reproduce.
 */
internal class UiSoundBridge(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val audioManager = appContext.getSystemService(AudioManager::class.java)
    private val soundPool: SoundPool =
        SoundPool.Builder()
            .setMaxStreams(MAX_STREAMS)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
    private val soundIds: Map<String, Int> =
        mapOf(
            "ACCESS_GRANTED" to soundPool.load(appContext, R.raw.ui_access_granted, 1),
            "NAVIGATION" to soundPool.load(appContext, R.raw.ui_navigation, 1),
            "MISSION_CREATED" to soundPool.load(appContext, R.raw.ui_mission_created, 1),
            "MISSION_COMPLETED" to soundPool.load(appContext, R.raw.ui_mission_completed, 1),
            "LEVEL_UP" to soundPool.load(appContext, R.raw.ui_level_up, 1),
        )

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    fun release() {
        soundPool.release()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "play" -> {
                val sound = call.argument<String>("sound")
                val soundId = soundIds[sound]
                if (soundId == null) {
                    result.error("INVALID_ARGUMENT", "Unknown sound: $sound", null)
                    return
                }
                if (audioManager?.ringerMode == AudioManager.RINGER_MODE_NORMAL) {
                    soundPool.play(soundId, VOLUME, VOLUME, 1, 0, 1f)
                }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/ui_sound"
        const val MAX_STREAMS = 3
        const val VOLUME = 0.6f
    }
}
