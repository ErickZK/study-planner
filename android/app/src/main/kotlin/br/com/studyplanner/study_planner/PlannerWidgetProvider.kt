package br.com.studyplanner.study_planner

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

class PlannerWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        manager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val snapshot = readSnapshot(context)
        appWidgetIds.forEach { manager.updateAppWidget(it, views(context, snapshot)) }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_TOGGLE -> updateTimer(context, startBreak = false)
            ACTION_BREAK -> updateTimer(context, startBreak = true)
            else -> return
        }
        updateAll(context)
    }

    private fun views(context: Context, snapshot: Snapshot): RemoteViews =
        RemoteViews(context.packageName, R.layout.planner_widget).apply {
            setTextViewText(R.id.widget_project, snapshot.project)
            setTextViewText(R.id.widget_phase, snapshot.phaseLabel)
            setTextViewText(
                R.id.widget_summary,
                "${snapshot.completed} de ${snapshot.total} tarefas concluídas" +
                    if (snapshot.nextTitle.isBlank()) "" else " · ${snapshot.nextTitle}",
            )

            if (snapshot.running) {
                setViewVisibility(R.id.widget_countdown, View.VISIBLE)
                setViewVisibility(R.id.widget_timer_text, View.GONE)
                setChronometer(
                    R.id.widget_countdown,
                    SystemClock.elapsedRealtime() + snapshot.remainingSeconds * 1000L,
                    null,
                    true,
                )
                setChronometerCountDown(R.id.widget_countdown, true)
            } else {
                setViewVisibility(R.id.widget_countdown, View.GONE)
                setViewVisibility(R.id.widget_timer_text, View.VISIBLE)
                setTextViewText(R.id.widget_timer_text, clock(snapshot.remainingSeconds))
            }

            setTextViewText(
                R.id.widget_toggle,
                when (snapshot.state) {
                    "running" -> "Pausar"
                    "paused", "break" -> "Continuar"
                    else -> "Abrir"
                },
            )
            setTextViewText(
                R.id.widget_break,
                if (snapshot.state == "break") "Pular pausa" else "Descanso",
            )
            setOnClickPendingIntent(R.id.widget_root, openPlanner(context))
            setOnClickPendingIntent(
                R.id.widget_toggle,
                if (snapshot.state.isBlank()) openPlanner(context) else action(context, ACTION_TOGGLE, 2),
            )
            setOnClickPendingIntent(R.id.widget_break, action(context, ACTION_BREAK, 3))
        }

    companion object {
        private const val ACTION_TOGGLE =
            "br.com.studyplanner.study_planner.action.TOGGLE_POMODORO"
        private const val ACTION_BREAK =
            "br.com.studyplanner.study_planner.action.TOGGLE_BREAK"
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val component = ComponentName(context, PlannerWidgetProvider::class.java)
            val ids = manager.getAppWidgetIds(component)
            if (ids.isNotEmpty()) {
                val update = Intent(context, PlannerWidgetProvider::class.java).apply {
                    action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                    putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
                }
                context.sendBroadcast(update)
            }
        }

        private fun database(context: Context) = File(context.filesDir, "study_planner.sqlite")

        private fun readSnapshot(context: Context): Snapshot {
            val file = database(context)
            if (!file.exists()) return Snapshot()
            return runCatching {
                SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READONLY).use { db ->
                    val project = db.rawQuery(
                        "SELECT name FROM projects ORDER BY created_at,id LIMIT 1",
                        null,
                    ).use { cursor -> if (cursor.moveToFirst()) cursor.getString(0) else "TJSP Planner" }

                    val timer = db.rawQuery(
                        """SELECT ss.status,ss.accumulated_seconds,ss.started_at,a.title,
                           s.focus_minutes,s.break_minutes,s.long_break_minutes,s.rounds_per_long_break
                           FROM study_sessions ss
                           JOIN activities a ON a.id=ss.activity_id
                           JOIN schedules s ON s.id=a.schedule_id
                           WHERE ss.status IN ('running','paused','break')
                           ORDER BY ss.updated_at DESC,ss.id DESC LIMIT 1""",
                        null,
                    ).use { cursor ->
                        if (!cursor.moveToFirst()) null
                        else TimerRow(
                            cursor.getString(0),
                            cursor.getInt(1),
                            if (cursor.isNull(2)) null else cursor.getLong(2),
                            cursor.getString(3),
                            cursor.getInt(4) * 60,
                            cursor.getInt(5) * 60,
                            cursor.getInt(6) * 60,
                            cursor.getInt(7),
                        )
                    }
                    val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
                    val tasks = db.rawQuery(
                        """SELECT COUNT(*),COALESCE(SUM(CASE WHEN status='done' THEN 1 ELSE 0 END),0),
                           COALESCE(MAX(CASE WHEN status!='done' THEN title ELSE '' END),'')
                           FROM activities WHERE local_date=?""",
                        arrayOf(today),
                    ).use { cursor ->
                        cursor.moveToFirst()
                        Triple(cursor.getInt(0), cursor.getInt(1), cursor.getString(2))
                    }
                    val remaining = remaining(timer)
                    Snapshot(
                        project = project,
                        state = timer?.state.orEmpty(),
                        remainingSeconds = remaining,
                        running = timer?.state == "running" || timer?.state == "break",
                        completed = tasks.second,
                        total = tasks.first,
                        nextTitle = timer?.title ?: tasks.third,
                    )
                }
            }.getOrDefault(Snapshot(project = "TJSP Planner", phaseError = true))
        }

        private fun remaining(timer: TimerRow?): Int {
            if (timer == null) return 25 * 60
            val delta = timer.startedAt?.let { max(0L, (System.currentTimeMillis() - it) / 1000L) } ?: 0L
            return if (timer.state == "break") {
                val completed = timer.accumulated / timer.focusSeconds
                val breakSeconds = if (completed > 0 && completed % timer.roundsPerLongBreak == 0)
                    timer.longBreakSeconds else timer.breakSeconds
                max(0, breakSeconds - delta.toInt())
            } else {
                val elapsed = timer.accumulated % timer.focusSeconds +
                    if (timer.state == "running") delta.toInt() else 0
                max(0, timer.focusSeconds - elapsed)
            }
        }

        private fun updateTimer(context: Context, startBreak: Boolean) {
            val file = database(context)
            if (!file.exists()) return
            runCatching {
                SQLiteDatabase.openDatabase(file.path, null, SQLiteDatabase.OPEN_READWRITE).use { db ->
                    val row = db.rawQuery(
                        """SELECT id,status,accumulated_seconds,started_at FROM study_sessions
                           WHERE status IN ('running','paused','break')
                           ORDER BY updated_at DESC,id DESC LIMIT 1""",
                        null,
                    ).use { cursor ->
                        if (!cursor.moveToFirst()) return@use null
                        ControlRow(
                            cursor.getLong(0),
                            cursor.getString(1),
                            cursor.getInt(2),
                            if (cursor.isNull(3)) null else cursor.getLong(3),
                        )
                    } ?: return@use
                    val now = System.currentTimeMillis()
                    var accumulated = row.accumulated
                    if (row.state == "running" && row.startedAt != null) {
                        accumulated += max(0L, (now - row.startedAt) / 1000L).toInt()
                    }
                    val nextState = when {
                        startBreak && row.state != "break" -> "break"
                        row.state == "running" -> "paused"
                        else -> "running"
                    }
                    val startedAt = if (nextState == "paused") null else now
                    db.execSQL(
                        """UPDATE study_sessions SET status=?,actual_seconds=?,accumulated_seconds=?,
                           started_at=?,updated_at=? WHERE id=?""",
                        arrayOf<Any?>(nextState, accumulated, accumulated, startedAt, now, row.id),
                    )
                }
            }
        }

        private fun openPlanner(context: Context): PendingIntent = PendingIntent.getActivity(
            context,
            1,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        private fun action(context: Context, name: String, requestCode: Int): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                requestCode,
                Intent(context, PlannerWidgetProvider::class.java).apply { action = name },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )

        private fun clock(seconds: Int) = "%02d:%02d".format(seconds / 60, seconds % 60)
    }
}

private data class Snapshot(
    val project: String = "TJSP Planner",
    val state: String = "",
    val remainingSeconds: Int = 25 * 60,
    val running: Boolean = false,
    val completed: Int = 0,
    val total: Int = 0,
    val nextTitle: String = "",
    val phaseError: Boolean = false,
) {
    val phaseLabel: String
        get() = when {
            phaseError -> "Dados indisponíveis"
            state == "running" -> "Pomodoro · foco"
            state == "paused" -> "Pomodoro · pausado"
            state == "break" -> "Pomodoro · descanso"
            else -> "Pomodoro · pronto para começar"
        }
}

private data class TimerRow(
    val state: String,
    val accumulated: Int,
    val startedAt: Long?,
    val title: String,
    val focusSeconds: Int,
    val breakSeconds: Int,
    val longBreakSeconds: Int,
    val roundsPerLongBreak: Int,
)

private data class ControlRow(
    val id: Long,
    val state: String,
    val accumulated: Int,
    val startedAt: Long?,
)
