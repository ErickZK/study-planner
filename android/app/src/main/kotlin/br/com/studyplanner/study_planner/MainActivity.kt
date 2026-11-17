package br.com.studyplanner.study_planner

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "tjsp_planner/android_widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "refresh" -> {
                    PlannerWidgetProvider.updateAll(this)
                    result.success(null)
                }
                "pin" -> {
                    val manager = AppWidgetManager.getInstance(this)
                    val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        manager.isRequestPinAppWidgetSupported
                    val requested = supported && manager.requestPinAppWidget(
                        ComponentName(this, PlannerWidgetProvider::class.java),
                        null,
                        null,
                    )
                    result.success(requested)
                }
                else -> result.notImplemented()
            }
        }
    }
}
