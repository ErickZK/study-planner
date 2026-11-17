using System.Threading;
using System.Windows;
using System.IO;

namespace TJSP.Planner.TaskbarWidget;

internal static class Program
{
    private const string MutexName = "Local\\TJSPPlannerTaskbarWidget";
    private const string ShowEventName = "Local\\TJSPPlannerTaskbarWidgetShow";

    [STAThread]
    private static void Main(string[] args)
    {
        if (args.Contains("--pause-pomodoro"))
        {
            PlannerSnapshot.PausePomodoro();
            return;
        }
        if (args.Contains("--start-break"))
        {
            PlannerSnapshot.StartPomodoroBreak();
            return;
        }
        if (args.Contains("--resume-pomodoro"))
        {
            PlannerSnapshot.ResumePomodoro();
            return;
        }
        var previewMode = args.Contains("--preview") ||
            Path.GetFileNameWithoutExtension(Environment.ProcessPath ?? "")
                .Contains("Preview", StringComparison.OrdinalIgnoreCase);
        if (previewMode)
        {
            var previewApplication = new Application
            {
                ShutdownMode = ShutdownMode.OnMainWindowClose,
            };
            var preview = new PlannerSnapshot(
                "TJSP 2026 — Escrevente",
                true,
                240,
                9000,
                false,
                "running",
                900,
                1,
                3,
                3,
                5,
                1,
                90,
                "Direito Administrativo")
            {
                WeekSeconds = 8 * 60 * 60 + 20 * 60,
                MonthSeconds = 27 * 60 * 60 + 45 * 60,
                MonthQuestions = 120,
                MonthCorrect = 89,
                StudyDays = 11,
                FocusSeconds = 25 * 60,
                BreakSeconds = 5 * 60,
                LongBreakSeconds = 15 * 60,
                RoundsPerLongBreak = 4,
            };
            previewApplication.Run(new PlannerFlyoutWindow(
                preview,
                (_, _) => { },
                (_) => { },
                () => { },
                () => { },
                () => { },
                true));
            return;
        }

        using var mutex = new Mutex(true, MutexName, out var ownsMutex);
        using var showEvent = new EventWaitHandle(false, EventResetMode.AutoReset, ShowEventName);
        if (!ownsMutex)
        {
            showEvent.Set();
            return;
        }

        var application = new Application
        {
            ShutdownMode = ShutdownMode.OnExplicitShutdown,
        };
        var widget = new TaskbarWidgetWindow();
        var registration = ThreadPool.RegisterWaitForSingleObject(
            showEvent,
            (_, _) => widget.Dispatcher.BeginInvoke(widget.ShowFlyout),
            null,
            Timeout.Infinite,
            false);
        application.Run(widget);
        registration.Unregister(null);
    }
}
