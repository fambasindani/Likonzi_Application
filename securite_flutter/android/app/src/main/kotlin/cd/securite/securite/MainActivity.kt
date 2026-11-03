package cd.securite.securite

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var canal: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        canal = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CANAL).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // Route demandée au lancement (widget SOS, app au premier plan).
                    "routeInitiale" -> result.success(routeDemandee(intent))
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // Application déjà ouverte : on pousse la route vers Flutter.
        val route = routeDemandee(intent) ?: return
        runOnUiThread { canal?.invokeMethod("ouvrirRoute", route) }
    }

    private fun routeDemandee(intent: Intent?): String? =
        intent?.getStringExtra(EXTRA_ROUTE)

    companion object {
        private const val CANAL = "cd.securite.securite/route"
        private const val EXTRA_ROUTE = "flutter_route"
    }
}
