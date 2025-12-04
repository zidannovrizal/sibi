package com.example.bima_flutter

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.GeneratedPluginRegistrant
import org.tensorflow.lite.flex.FlexDelegate
import java.util.concurrent.ConcurrentHashMap

class MainActivity : FlutterActivity() {
    private val channelName = "flex_delegate"
    private val delegates = ConcurrentHashMap<Long, FlexDelegate>()

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        GeneratedPluginRegistrant.registerWith(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "create" -> {
                        try {
                            val delegate = FlexDelegate()
                            val handle = delegate.nativeHandle
                            delegates[handle] = delegate
                            result.success(handle)
                        } catch (e: Throwable) {
                            result.error("FLEX_CREATE_ERROR", e.message, null)
                        }
                    }
                    "delete" -> {
                        val handle = (call.arguments as? Number)?.toLong()
                        if (handle == null) {
                            result.error("INVALID_HANDLE", "Delegate handle missing", null)
                        } else {
                            delegates.remove(handle)?.close()
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
