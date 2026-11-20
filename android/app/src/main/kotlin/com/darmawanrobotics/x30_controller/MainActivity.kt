package com.darmawanrobotics.x30_controller

import android.hardware.input.InputManager
import android.os.Bundle
import android.os.Handler
import android.view.KeyEvent
import android.view.MotionEvent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.flame_engine.gamepads_android.GamepadsCompatibleActivity

/**
 * Forwards gamepad input to the gamepads plugin, the Skydroid handheld's sticks to Dart
 * (x30/skydroid) and keeps the screen on while driving.
 */
class MainActivity : FlutterActivity(), GamepadsCompatibleActivity {
    private var keyListener: ((KeyEvent) -> Boolean)? = null
    private var motionListener: ((MotionEvent) -> Boolean)? = null
    private val sticks by lazy { SkydroidSticks(this) }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, "x30/skydroid").setMethodCallHandler { call, result ->
            when (call.method) {
                "available" -> result.success(SkydroidSticks.available())
                else -> result.notImplemented()
            }
        }
        // channel values as a list of ints, the link state as text
        EventChannel(messenger, "x30/skydroid/channels").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    sticks.start(object : SkydroidSticks.Listener {
                        override fun onChannels(channels: IntArray) {
                            events.success(channels.toList())
                        }

                        override fun onState(state: String) {
                            events.success(state)
                        }
                    })
                }

                override fun onCancel(arguments: Any?) {
                    sticks.stop()
                }
            },
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }

    override fun dispatchGenericMotionEvent(motionEvent: MotionEvent): Boolean {
        if (motionListener?.invoke(motionEvent) == true) {
            return true
        }
        return super.dispatchGenericMotionEvent(motionEvent)
    }

    override fun dispatchKeyEvent(keyEvent: KeyEvent): Boolean {
        if (keyListener?.invoke(keyEvent) == true) {
            return true
        }
        return super.dispatchKeyEvent(keyEvent)
    }

    override fun registerInputDeviceListener(
        listener: InputManager.InputDeviceListener,
        handler: Handler?,
    ) {
        val inputManager = getSystemService(INPUT_SERVICE) as InputManager
        inputManager.registerInputDeviceListener(listener, null)
    }

    override fun registerKeyEventHandler(handler: (KeyEvent) -> Boolean) {
        keyListener = handler
    }

    override fun registerMotionEventHandler(handler: (MotionEvent) -> Boolean) {
        motionListener = handler
    }
}
