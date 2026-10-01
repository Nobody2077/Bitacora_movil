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
    private val activeStreams = mutableMapOf<String, Int>()
    private val soundIds: Map<String, Int> =
        mapOf(
            "ACCESS_GRANTED" to soundPool.load(appContext, R.raw.ui_access_granted, 1),
            "NAVIGATION" to soundPool.load(appContext, R.raw.ui_navigation, 1),
            "MISSION_CREATED" to soundPool.load(appContext, R.raw.ui_mission_created, 1),
            "MISSION_COMPLETED" to soundPool.load(appContext, R.raw.ui_mission_completed, 1),
            "LEVEL_UP" to soundPool.load(appContext, R.raw.ui_level_up, 1),
            "ACCESS_KEYPAD" to soundPool.load(appContext, R.raw.ui_access_keypad, 1),
            "ACCESS_LOADING" to soundPool.load(appContext, R.raw.ui_access_loading, 1),
            "ACCESS_DENIED" to soundPool.load(appContext, R.raw.ui_access_denied, 1),
        )

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, CHANNEL).setMethodCallHandler(this)
    }

    fun release() {
        activeStreams.clear()
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
                    val volume = if (sound == "ACCESS_LOADING") LOADING_VOLUME else VOLUME
                    val streamId = soundPool.play(soundId, volume, volume, 1, 0, 1f)
                    if (streamId != 0 && sound != null) {
                        activeStreams[sound] = streamId
                    }
                }
                result.success(null)
            }

            "stop" -> {
                // Solo la carga de la terminal dura más que su acción; se corta
                // en cuanto termina para no alargar la entrada.
                val sound = call.argument<String>("sound")
                activeStreams.remove(sound)?.let { soundPool.stop(it) }
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    private companion object {
        const val CHANNEL = "com.jcyq.bitacorarpg/ui_sound"
        const val MAX_STREAMS = 3
        const val VOLUME = 0.6f
        const val LOADING_VOLUME = 0.35f
    }
}
