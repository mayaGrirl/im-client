package com.im.im_client

import android.content.Context
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AudioManagerPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var audioManager: AudioManager
    private var context: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        audioManager = context!!.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        channel = MethodChannel(binding.binaryMessenger, "com.im.im_client/audio_manager")
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setSpeakerphoneOn" -> {
                val enabled = call.argument<Boolean>("enabled") ?: false
                setSpeakerphoneOn(enabled)
                result.success(null)
            }
            "isSpeakerphoneOn" -> {
                result.success(audioManager.isSpeakerphoneOn)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun setSpeakerphoneOn(enabled: Boolean) {
        try {
            // 设置音频模式为通话模式
            audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
            
            // 设置扬声器状态
            audioManager.isSpeakerphoneOn = enabled
            
            // Android 11+ 需要额外处理
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (enabled) {
                    val speakerDevice = audioManager.availableCommunicationDevices.firstOrNull { 
                        it.type == android.media.AudioDeviceInfo.TYPE_BUILTIN_SPEAKER 
                    }
                    if (speakerDevice != null) {
                        audioManager.setCommunicationDevice(speakerDevice)
                    }
                } else {
                    audioManager.clearCommunicationDevice()
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        context = null
    }
}
