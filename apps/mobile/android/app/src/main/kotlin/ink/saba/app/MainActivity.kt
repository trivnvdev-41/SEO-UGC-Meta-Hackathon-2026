package ink.saba.app

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .also { ch ->
                ch.setMethodCallHandler { call, result ->
                    if (call.method == "openUrl") {
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
    }

    companion object {
        private const val CHANNEL = "saba/share"
    }
}
