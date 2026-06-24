package com.almarfa.al_quran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen "Next prayer" widget. Renders ONLY — every minute of prayer-times
 * math (Karachi method + Shafi Asr, the forbidden windows) lives in Dart and
 * reaches us as the `prayer_widget_payload` JSON written by WidgetPublisher. We
 * just find the next marker after `now` across the serialised days and draw it.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val raw = widgetData.getString(PAYLOAD_KEY, null)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            render(context, views, raw)
            views.setOnClickPendingIntent(R.id.widget_root, launchIntent(context))
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun render(context: Context, views: RemoteViews, raw: String?) {
        if (raw == null) {
            showPrompt(context, views)
            return
        }
        try {
            val root = JSONObject(raw)
            if (!root.optBoolean("hasLocation", false)) {
                showPrompt(context, views)
                return
            }

            val next = nextMarkerAfter(root, System.currentTimeMillis())
            if (next == null) {
                showPrompt(context, views)
                return
            }

            val label = if (root.isNull("locationLabel")) {
                context.getString(R.string.widget_default_location)
            } else {
                root.optString("locationLabel", "")
                    .ifBlank { context.getString(R.string.widget_default_location) }
            }

            views.setViewVisibility(R.id.widget_location, View.VISIBLE)
            views.setTextViewText(R.id.widget_location, label)
            views.setTextViewText(R.id.widget_label, context.getString(R.string.widget_label))
            views.setTextViewText(R.id.widget_prayer, next.name)
            views.setTextViewText(R.id.widget_time, TIME_FORMAT.format(Date(next.at)))
        } catch (e: Exception) {
            showPrompt(context, views)
        }
    }

    /** First marker strictly after [now]. Days/markers are stored chronologically. */
    private fun nextMarkerAfter(root: JSONObject, now: Long): Marker? {
        val days = root.optJSONArray("days") ?: return null
        for (i in 0 until days.length()) {
            val markers = days.getJSONObject(i).optJSONArray("markers") ?: continue
            for (j in 0 until markers.length()) {
                val m = markers.getJSONObject(j)
                val at = ISO_FORMAT.parse(m.getString("at"))?.time ?: continue
                if (at > now) return Marker(m.getString("name"), at)
            }
        }
        return null
    }

    private fun showPrompt(context: Context, views: RemoteViews) {
        views.setViewVisibility(R.id.widget_location, View.GONE)
        views.setTextViewText(R.id.widget_label, context.getString(R.string.widget_label))
        views.setTextViewText(R.id.widget_prayer, context.getString(R.string.widget_no_location_title))
        views.setTextViewText(R.id.widget_time, context.getString(R.string.widget_no_location_subtitle))
    }

    private fun launchIntent(context: Context): PendingIntent {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private data class Marker(val name: String, val at: Long)

    companion object {
        private const val PAYLOAD_KEY = "prayer_widget_payload"

        // Dart writes device-local wall-clock with no offset; parse in the
        // device's default zone (same device) to recover the right instant.
        private val ISO_FORMAT =
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
        private val TIME_FORMAT =
            SimpleDateFormat("h:mm a", Locale.getDefault())
    }
}
