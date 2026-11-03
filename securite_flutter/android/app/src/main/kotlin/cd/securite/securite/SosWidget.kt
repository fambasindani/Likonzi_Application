package cd.securite.securite

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/**
 * Widget d'accueil « SOS » : un appui ouvre l'application directement sur
 * l'écran SOS (compte à rebours, annulation, envoi aux proches).
 */
class SosWidget : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            val intent = Intent(context, MainActivity::class.java).apply {
                putExtra(EXTRA_ROUTE, ROUTE_SOS)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                appWidgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val vues = RemoteViews(context.packageName, R.layout.widget_sos)
            vues.setOnClickPendingIntent(R.id.widget_sos_root, pendingIntent)
            appWidgetManager.updateAppWidget(appWidgetId, vues)
        }
    }

    companion object {
        const val EXTRA_ROUTE = "flutter_route"
        const val ROUTE_SOS = "/sos"
    }
}
