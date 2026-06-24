package com.almarfa.al_quran

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Wide "today's prayers" widget: the five salah across a row (Sunrise excluded —
 * it isn't a prayer), with the NEXT one highlighted. Renders ONLY — it reads the
 * same `prayer_widget_payload` JSON that Dart writes (today is days[0]) and never
 * recomputes anything.
 */
class PrayerScheduleWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val raw = widgetData.getString(PAYLOAD_KEY, null)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_schedule_widget)
            render(views, raw)
            views.setOnClickPendingIntent(R.id.widget_schedule_root, launchIntent(context))
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    private fun render(views: RemoteViews, raw: String?) {
        val salah = if (raw == null) emptyList() else todaySalah(raw)
        if (salah.isEmpty()) {
            // No data/location yet — keep the static names from the layout and
            // blank the times so the day's skeleton still reads.
            for (i in 0 until CELLS) views.setTextViewText(TIME_IDS[i], "--:--")
            return
        }

        val now = System.currentTimeMillis()
        val nextIndex = salah.indexOfFirst { it.second > now }
        for (i in 0 until CELLS) {
            if (i >= salah.size) continue
            val (name, at) = salah[i]
            val highlight = i == nextIndex
            views.setTextViewText(NAME_IDS[i], name)
            views.setTextViewText(TIME_IDS[i], TIME_FORMAT.format(Date(at)))
            views.setTextColor(NAME_IDS[i], if (highlight) HL_NAME else DIM_NAME)
            views.setTextColor(TIME_IDS[i], if (highlight) HL_TIME else DIM_TIME)
            views.setInt(
                CELL_IDS[i],
                "setBackgroundResource",
                if (highlight) R.drawable.prayer_cell_highlight else 0,
            )
        }
    }

    /** The five salah of days[0] in order, or empty if the payload can't be read. */
    private fun todaySalah(raw: String): List<Pair<String, Long>> {
        return try {
            val root = JSONObject(raw)
            if (!root.optBoolean("hasLocation", false)) return emptyList()
            val days = root.optJSONArray("days") ?: return emptyList()
            if (days.length() == 0) return emptyList()
            val markers = days.getJSONObject(0).optJSONArray("markers") ?: return emptyList()
            val out = ArrayList<Pair<String, Long>>(CELLS)
            for (j in 0 until markers.length()) {
                val m = markers.getJSONObject(j)
                if (!m.optBoolean("isSalah", true)) continue // skip Sunrise
                val at = ISO_FORMAT.parse(m.getString("at"))?.time ?: continue
                out.add(m.getString("name") to at)
            }
            out
        } catch (e: Exception) {
            emptyList()
        }
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

    companion object {
        private const val PAYLOAD_KEY = "prayer_widget_payload"
        private const val CELLS = 5

        private val NAME_IDS =
            intArrayOf(R.id.name_0, R.id.name_1, R.id.name_2, R.id.name_3, R.id.name_4)
        private val TIME_IDS =
            intArrayOf(R.id.time_0, R.id.time_1, R.id.time_2, R.id.time_3, R.id.time_4)
        private val CELL_IDS =
            intArrayOf(R.id.cell_0, R.id.cell_1, R.id.cell_2, R.id.cell_3, R.id.cell_4)

        private val DIM_NAME = Color.parseColor("#7FA89E")
        private val DIM_TIME = Color.parseColor("#DCE8E3")
        private val HL_NAME = Color.parseColor("#E4D9B8")
        private val HL_TIME = Color.parseColor("#FFFFFF")

        // Dart writes device-local wall-clock with no offset; parse in the
        // device's default zone (same device) to recover the right instant.
        private val ISO_FORMAT = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US)
        // No AM/PM here: 5 columns stay uniform width, and prayer times are
        // unambiguous by time of day. (The single next-prayer widget keeps AM/PM.)
        private val TIME_FORMAT = SimpleDateFormat("h:mm", Locale.getDefault())
    }
}
