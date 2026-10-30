package dev.seougc.seo_ugc

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingText: String? = null
    private var channel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingText = extract(intent)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .also { ch ->
                ch.setMethodCallHandler { call, result ->
                    if (call.method == "getInitialSharedText") {
                        result.success(pendingText)
                        pendingText = null
                    } else {
                        result.notImplemented()
                    }
                }
            }
        pendingText?.let { dispatch(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        extract(intent)?.let { dispatch(it) }
    }

    private fun extract(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

    private fun dispatch(text: String) {
        channel?.invokeMethod("shared", text)
        pendingText = null
    }

    companion object {
        private const val CHANNEL = "dev.seougc/share"
    }
}
