package com.edu.edupulse

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Paint
import android.view.View
import android.widget.RemoteViews

/**
 * Widget màn hình chính EduPulse — "chu trình sống ngoài app".
 *
 * Không dùng package trung gian: đọc trực tiếp SharedPreferences của Flutter
 * (file `FlutterSharedPreferences.xml`, các key có prefix `flutter.widget_*`)
 * do [HomeWidgetService] bên Dart ghi. Mỗi lần app được mở (kể cả từ widget)
 * Dart sync lại → widget cập nhật. Tap widget → mở app (tap task → mở app).
 */
class EdupulseWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // Flutter SharedPreferences đổi → MainActivity.onActivityResult không
        // chạy ở đây, nên chỉ cần vẽ lại từ dữ liệu hiện có khi có yêu cầu.
        if (intent.action == AppWidgetManager.ACTION_APPWIDGET_UPDATE ||
            intent.action == Intent.ACTION_TIME_CHANGED ||
            intent.action == Intent.ACTION_TIMEZONE_CHANGED
        ) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, EdupulseWidgetProvider::class.java)
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
        }
    }

    private fun buildViews(context: Context): RemoteViews {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )

        val views = RemoteViews(context.packageName, R.layout.edupulse_widget)

        // --- Mở app khi chạm widget ---
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, com.edu.edupulse.MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        views.setOnClickPendingIntent(R.id.widget_root, openApp)

        // --- Đếm ngược kỳ thi ---
        val examName = prefs.getString("flutter.widget_exam_name", "") ?: ""
        val daysLeft = prefs.getInt("flutter.widget_days_left", -1)
        if (examName.isNotEmpty() && daysLeft >= 0) {
            views.setViewVisibility(R.id.exam_section, View.VISIBLE)
            views.setViewVisibility(R.id.empty_state, View.GONE)
            views.setTextViewText(
                R.id.exam_days,
                if (daysLeft == 0) "Hôm nay thi!" else "$daysLeft"
            )
            views.setTextViewText(
                R.id.exam_days_suffix,
                if (daysLeft == 0) "" else "ngày"
            )
            views.setTextViewText(R.id.exam_name, examName)
        } else {
            views.setViewVisibility(R.id.exam_section, View.GONE)
            views.setViewVisibility(R.id.empty_state, View.VISIBLE)
        }

        // --- 2 nhiệm vụ hôm nay ---
        val t1 = prefs.getString("flutter.widget_task1_title", "") ?: ""
        val t2 = prefs.getString("flutter.widget_task2_title", "") ?: ""
        bindTask(views, 1, t1)
        bindTask(views, 2, t2)

        return views
    }

    private fun bindTask(views: RemoteViews, index: Int, title: String) {
        val titleId = if (index == 1) R.id.task1_title else R.id.task2_title
        if (title.isEmpty()) {
            views.setViewVisibility(titleId, View.GONE)
        } else {
            views.setViewVisibility(titleId, View.VISIBLE)
            views.setTextViewText(titleId, "☐  $title")
        }
    }
}
