package dev.seougc.seo_ugc

import android.content.Intent
import android.os.Bundle
import android.util.Log
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
                    } else if (call.method == "openUrl") {
                        // Buka link artikel di browser: tanpa dependency url_launcher.
                        try {
                            val url = call.arguments as String
                            startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("open_failed", e.message, null)
                        }
                    } else {
                        result.notImplemented()
                    }
                }
            }
        pendingText?.let { dispatch(it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val text = extract(intent)
        Log.d(TAG, "onNewIntent action=${intent.action} type=${intent.type} text=${text != null}")
        if (text != null) dispatch(text)
    }

    private fun extract(intent: Intent?): String? =
        if (intent?.action == Intent.ACTION_SEND && intent.type == "text/plain") {
            intent.getStringExtra(Intent.EXTRA_TEXT)
        } else {
            null
        }

    // pendingText tetap disimpan: kalau channel belum siap, Dart mengambilnya
    // lewat getInitialSharedText saat app resume.
    private fun dispatch(text: String) {
        pendingText = text
        channel?.invokeMethod("shared", text)
    }

    companion object {
        private const val CHANNEL = "dev.seougc/share"
        private const val TAG = "SEOUGC"
    }
}
