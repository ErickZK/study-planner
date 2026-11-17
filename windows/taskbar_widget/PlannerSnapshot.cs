using System.Globalization;
using System.IO;
using Microsoft.Data.Sqlite;

namespace TJSP.Planner.TaskbarWidget;

internal sealed record PlannerSnapshot(
    string Project,
    bool HasSchedule,
    int GoalMinutes,
    int TodaySeconds,
    bool IsRunning,
    string TimerState,
    int PhaseRemainingSeconds,
    int CompletedPomodoros,
    int PlannedPomodoros,
    int Completed,
    int Total,
    long NextId,
    int NextMinutes,
    string NextTitle)
{
    internal int WeekSeconds { get; init; }
    internal int MonthSeconds { get; init; }
    internal int MonthQuestions { get; init; }
    internal int MonthCorrect { get; init; }
    internal int StudyDays { get; init; }
    internal int FocusSeconds { get; init; } = 25 * 60;
    internal int BreakSeconds { get; init; } = 5 * 60;
    internal int LongBreakSeconds { get; init; } = 15 * 60;
    internal int RoundsPerLongBreak { get; init; } = 4;

    internal int CurrentBreakSeconds =>
        CompletedPomodoros > 0 && CompletedPomodoros % RoundsPerLongBreak == 0
            ? LongBreakSeconds
            : BreakSeconds;

    internal static PlannerSnapshot Empty { get; } = new(
        "TJSP Planner", false, 0, 0, false, "", 0, 0, 0, 0, 0, 0, 0, "");

    internal int Percent => GoalMinutes <= 0
        ? 0
        : Math.Clamp(
            (int)Math.Round(TodaySeconds * 100.0 / (GoalMinutes * 60)),
            0,
            100);

    internal bool HasPomodoro => TimerState is "running" or "paused" or "break";

    internal int PhasePercent
    {
        get
        {
            if (!HasPomodoro) return Percent;
            var total = TimerState == "break" ? CurrentBreakSeconds : FocusSeconds;
            return Math.Clamp(
                (int)Math.Round((total - PhaseRemainingSeconds) * 100.0 / total),
                0,
                100);
        }
    }

    internal static bool PausePomodoro() => UpdatePomodoroState(startBreak: false);

    internal static bool StartPomodoroBreak() => UpdatePomodoroState(startBreak: true);

    internal static bool ResumePomodoro()
    {
        var databasePath = DatabasePath();
        if (!File.Exists(databasePath)) return false;
        try
        {
            using var connection = new SqliteConnection(new SqliteConnectionStringBuilder
            {
                DataSource = databasePath,
                Mode = SqliteOpenMode.ReadWrite,
            }.ToString());
            connection.Open();
            using var update = connection.CreateCommand();
            update.CommandText = """
                UPDATE study_sessions
                SET status='running',started_at=$now,updated_at=$now
                WHERE id=(
                    SELECT id FROM study_sessions
                    WHERE status IN ('paused','break')
                    ORDER BY updated_at DESC,id DESC LIMIT 1
                )
                """;
            update.Parameters.AddWithValue(
                "$now",
                DateTimeOffset.UtcNow.ToUnixTimeMilliseconds());
            return update.ExecuteNonQuery() == 1;
        }
        catch (Exception exception) when (
            exception is SqliteException or IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    private static bool UpdatePomodoroState(bool startBreak)
    {
        var databasePath = DatabasePath();
        if (!File.Exists(databasePath)) return false;
        try
        {
            using var connection = new SqliteConnection(new SqliteConnectionStringBuilder
            {
                DataSource = databasePath,
                Mode = SqliteOpenMode.ReadWrite,
            }.ToString());
            connection.Open();
            using var select = connection.CreateCommand();
            select.CommandText = """
                SELECT id,status,accumulated_seconds,started_at
                FROM study_sessions
                WHERE status IN ('running','paused')
                ORDER BY updated_at DESC,id DESC
                LIMIT 1
                """;
            using var reader = select.ExecuteReader();
            if (!reader.Read()) return false;
            var id = reader.GetInt64(0);
            var status = reader.GetString(1);
            var focusSeconds = reader.GetInt32(2);
            var startedAt = reader.IsDBNull(3) ? 0 : reader.GetInt64(3);
            reader.Close();
            if (status == "running" && startedAt > 0)
            {
                focusSeconds += (int)Math.Max(
                    0,
                    (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - startedAt) / 1000);
            }

            var now = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
            using var update = connection.CreateCommand();
            update.CommandText = startBreak
                ? "UPDATE study_sessions SET status='break',actual_seconds=$seconds,accumulated_seconds=$seconds,started_at=$now,updated_at=$now WHERE id=$id"
                : "UPDATE study_sessions SET status='paused',actual_seconds=$seconds,accumulated_seconds=$seconds,started_at=NULL,updated_at=$now WHERE id=$id";
            update.Parameters.AddWithValue("$seconds", focusSeconds);
            update.Parameters.AddWithValue("$now", now);
            update.Parameters.AddWithValue("$id", id);
            return update.ExecuteNonQuery() == 1;
        }
        catch (Exception exception) when (
            exception is SqliteException or IOException or UnauthorizedAccessException)
        {
            return false;
        }
    }

    internal static PlannerSnapshot Read()
    {
        var databasePath = DatabasePath();
        if (!File.Exists(databasePath)) return Empty;

        try
        {
            using var connection = new SqliteConnection(new SqliteConnectionStringBuilder
            {
                DataSource = databasePath,
                // The widget also owns automatic Pomodoro phase transitions,
                // so it must persist focus -> break and break -> focus.
                Mode = SqliteOpenMode.ReadWrite,
            }.ToString());
            connection.Open();

            using var scheduleCommand = connection.CreateCommand();
            scheduleCommand.CommandText = """
                SELECT s.id,s.name,s.daily_minutes,s.focus_minutes,s.break_minutes,
                       s.long_break_minutes,s.rounds_per_long_break
                FROM schedules s
                WHERE s.archived=0
                ORDER BY EXISTS(
                    SELECT 1 FROM activities a
                    JOIN study_sessions ss ON ss.activity_id=a.id
                    WHERE a.schedule_id=s.id
                      AND ss.status IN ('running','paused','break')
                ) DESC,s.id
                LIMIT 1
                """;
            using var scheduleReader = scheduleCommand.ExecuteReader();
            if (!scheduleReader.Read()) return Empty;
            var scheduleId = scheduleReader.GetInt64(0);
            var scheduleName = scheduleReader.GetString(1);
            var goalMinutes = scheduleReader.GetInt32(2);
            var focusSecondsSetting = scheduleReader.GetInt32(3) * 60;
            var breakSecondsSetting = scheduleReader.GetInt32(4) * 60;
            var longBreakSecondsSetting = scheduleReader.GetInt32(5) * 60;
            var roundsPerLongBreakSetting = scheduleReader.GetInt32(6);
            scheduleReader.Close();

            var today = DateTime.Now.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            using var activitiesCommand = connection.CreateCommand();
            activitiesCommand.CommandText = "SELECT id,title,status,planned_minutes FROM activities WHERE schedule_id=$schedule AND local_date=$today ORDER BY position,id";
            activitiesCommand.Parameters.AddWithValue("$schedule", scheduleId);
            activitiesCommand.Parameters.AddWithValue("$today", today);

            var total = 0;
            var completed = 0;
            long nextId = 0;
            var nextMinutes = 0;
            var nextTitle = "";
            using (var activitiesReader = activitiesCommand.ExecuteReader())
            {
                while (activitiesReader.Read())
                {
                    total++;
                    if (activitiesReader.GetString(2) == "done")
                    {
                        completed++;
                    }
                    else if (nextId == 0)
                    {
                        nextId = activitiesReader.GetInt64(0);
                        nextTitle = activitiesReader.GetString(1);
                        nextMinutes = activitiesReader.GetInt32(3);
                    }
                }
            }

            using var studiedCommand = connection.CreateCommand();
            studiedCommand.CommandText = """
                SELECT COALESCE(SUM(
                    CASE
                      WHEN s.status='running' AND s.started_at IS NOT NULL THEN
                        s.accumulated_seconds + MAX(
                          0,
                          CAST(strftime('%s','now') AS INTEGER) - (s.started_at / 1000)
                        )
                      WHEN s.status IN ('paused','break','finished') THEN s.actual_seconds
                      ELSE 0
                    END
                ),0) AS total_seconds,
                COALESCE(MAX(CASE WHEN s.status IN ('running','break') THEN 1 ELSE 0 END),0) AS is_running
                FROM study_sessions s
                JOIN activities a ON a.id=s.activity_id
                WHERE a.schedule_id=$schedule AND s.local_study_date=$today
                """;
            studiedCommand.Parameters.AddWithValue("$schedule", scheduleId);
            studiedCommand.Parameters.AddWithValue("$today", today);
            using var studiedReader = studiedCommand.ExecuteReader();
            studiedReader.Read();
            var todaySeconds = studiedReader.GetInt32(0);
            var isRunning = studiedReader.GetInt32(1) == 1;
            studiedReader.Close();

            var now = DateTime.Today;
            var weekStartDate = now.AddDays(-((7 + (int)now.DayOfWeek - (int)DayOfWeek.Monday) % 7));
            var weekStart = weekStartDate.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            var monthStart = new DateTime(now.Year, now.Month, 1)
                .ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
            using var metricsCommand = connection.CreateCommand();
            metricsCommand.CommandText = """
                SELECT
                  COALESCE(SUM(CASE WHEN ss.local_study_date >= $week AND ss.local_study_date < $today THEN ss.actual_seconds ELSE 0 END),0),
                  COALESCE(SUM(CASE WHEN ss.local_study_date >= $month AND ss.local_study_date < $today THEN ss.actual_seconds ELSE 0 END),0),
                  COALESCE(SUM(CASE WHEN ss.local_study_date >= $month THEN ss.question_count ELSE 0 END),0),
                  COALESCE(SUM(CASE WHEN ss.local_study_date >= $month THEN ss.correct_count ELSE 0 END),0),
                  COUNT(DISTINCT CASE WHEN ss.local_study_date >= $month AND ss.actual_seconds > 0 THEN ss.local_study_date END)
                FROM study_sessions ss
                JOIN activities a ON a.id=ss.activity_id
                WHERE a.schedule_id=$schedule
                """;
            metricsCommand.Parameters.AddWithValue("$schedule", scheduleId);
            metricsCommand.Parameters.AddWithValue("$today", today);
            metricsCommand.Parameters.AddWithValue("$week", weekStart);
            metricsCommand.Parameters.AddWithValue("$month", monthStart);
            using var metricsReader = metricsCommand.ExecuteReader();
            metricsReader.Read();
            var weekSeconds = todaySeconds + metricsReader.GetInt32(0);
            var monthSeconds = todaySeconds + metricsReader.GetInt32(1);
            var monthQuestions = metricsReader.GetInt32(2);
            var monthCorrect = metricsReader.GetInt32(3);
            var studyDays = metricsReader.GetInt32(4);
            metricsReader.Close();

            var timerState = "";
            var phaseRemainingSeconds = 0;
            var completedPomodoros = 0;
            var plannedPomodoros = 0;
            using var timerCommand = connection.CreateCommand();
            timerCommand.CommandText = """
                SELECT ss.id,ss.status,ss.accumulated_seconds,ss.started_at,a.planned_minutes
                FROM study_sessions ss
                JOIN activities a ON a.id=ss.activity_id
                WHERE a.schedule_id=$schedule
                  AND ss.status IN ('running','paused','break')
                ORDER BY ss.updated_at DESC,ss.id DESC
                LIMIT 1
                """;
            timerCommand.Parameters.AddWithValue("$schedule", scheduleId);
            using var timerReader = timerCommand.ExecuteReader();
            if (timerReader.Read())
            {
                var focusSeconds = focusSecondsSetting;
                var timerId = timerReader.GetInt64(0);
                timerState = timerReader.GetString(1);
                var accumulated = timerReader.GetInt32(2);
                var startedAt = timerReader.IsDBNull(3) ? 0 : timerReader.GetInt64(3);
                var plannedMinutes = timerReader.GetInt32(4);
                completedPomodoros = accumulated / focusSeconds;
                plannedPomodoros = Math.Max(
                    1,
                    (plannedMinutes * 60 + focusSeconds - 1) / focusSeconds);
                var phaseDelta = startedAt == 0
                    ? 0
                    : Math.Max(0, (DateTimeOffset.UtcNow.ToUnixTimeMilliseconds() - startedAt) / 1000);
                if (timerState == "break")
                {
                    var breakSeconds = completedPomodoros > 0 &&
                        completedPomodoros % roundsPerLongBreakSetting == 0
                            ? longBreakSecondsSetting
                            : breakSecondsSetting;
                    phaseRemainingSeconds = Math.Max(0, breakSeconds - (int)phaseDelta);
                    if (phaseRemainingSeconds == 0)
                    {
                        timerReader.Close();
                        var transitionNow = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                        using var transition = connection.CreateCommand();
                        transition.CommandText = "UPDATE study_sessions SET status='running',started_at=$now,updated_at=$now WHERE id=$id AND status='break'";
                        transition.Parameters.AddWithValue("$now", transitionNow);
                        transition.Parameters.AddWithValue("$id", timerId);
                        transition.ExecuteNonQuery();
                        timerState = "running";
                        phaseRemainingSeconds = focusSeconds;
                    }
                }
                else
                {
                    var focusElapsed = accumulated % focusSeconds;
                    if (timerState == "running") focusElapsed += (int)phaseDelta;
                    phaseRemainingSeconds = Math.Max(0, focusSeconds - focusElapsed);
                    if (timerState == "running" && phaseRemainingSeconds == 0)
                    {
                        timerReader.Close();
                        var completedSeconds = accumulated - (accumulated % focusSeconds) + focusSeconds;
                        var transitionNow = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds();
                        using var transition = connection.CreateCommand();
                        transition.CommandText = "UPDATE study_sessions SET status='break',actual_seconds=$seconds,accumulated_seconds=$seconds,started_at=$now,updated_at=$now WHERE id=$id AND status='running'";
                        transition.Parameters.AddWithValue("$seconds", completedSeconds);
                        transition.Parameters.AddWithValue("$now", transitionNow);
                        transition.Parameters.AddWithValue("$id", timerId);
                        transition.ExecuteNonQuery();
                        accumulated = completedSeconds;
                        completedPomodoros = accumulated / focusSeconds;
                        timerState = "break";
                        phaseRemainingSeconds = completedPomodoros % roundsPerLongBreakSetting == 0
                            ? longBreakSecondsSetting
                            : breakSecondsSetting;
                    }
                }
            }

            return new PlannerSnapshot(
                string.IsNullOrWhiteSpace(scheduleName) ? "TJSP Planner" : scheduleName,
                true,
                goalMinutes,
                todaySeconds,
                isRunning,
                timerState,
                phaseRemainingSeconds,
                completedPomodoros,
                plannedPomodoros,
                completed,
                total,
                nextId,
                nextMinutes,
                nextTitle)
            {
                WeekSeconds = weekSeconds,
                MonthSeconds = monthSeconds,
                MonthQuestions = monthQuestions,
                MonthCorrect = monthCorrect,
                StudyDays = studyDays,
                FocusSeconds = focusSecondsSetting,
                BreakSeconds = breakSecondsSetting,
                LongBreakSeconds = longBreakSecondsSetting,
                RoundsPerLongBreak = roundsPerLongBreakSetting,
            };
        }
        catch (Exception exception) when (
            exception is SqliteException or IOException or UnauthorizedAccessException)
        {
            return Empty with { Project = "Dados indisponíveis" };
        }
    }

    private static string DatabasePath() => Path.Combine(
        Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData),
        "br.com.studyplanner",
        "study_planner",
        "study_planner.sqlite");
}
