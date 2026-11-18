using System.Diagnostics;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Threading;
using System.Windows.Shapes;
using PathShape = System.Windows.Shapes.Path;

namespace TJSP.Planner.TaskbarWidget;

internal sealed class TaskbarWidgetWindow : Window
{
    private const double LogicalWidth = 176;
    private readonly DispatcherTimer _positionTimer;
    private readonly DispatcherTimer _dataTimer;
    private readonly TextBlock _mainText;
    private readonly TextBlock _secondaryText;
    private readonly TextBlock _ringValue;
    private readonly PathShape _progressArc;
    private readonly Button _toggleButton;
    private readonly Button _phaseButton;
    private readonly SolidColorBrush _surfaceBrush;
    private readonly SolidColorBrush _focusAccent = new(Color.FromRgb(255, 98, 95));
    private readonly SolidColorBrush _breakAccent = new(Color.FromRgb(66, 194, 104));
    private readonly WidgetTheme _theme;
    private nint _handle;
    private nint _taskbarHandle;
    private PlannerSnapshot _snapshot = PlannerSnapshot.Empty;
    private PlannerFlyoutWindow? _flyout;

    internal TaskbarWidgetWindow()
    {
        _theme = WidgetTheme.Current;
        Width = LogicalWidth;
        Height = 48;
        Title = "Meu Rumo — barra de tarefas";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = false;
        AllowsTransparency = true;
        Background = Brushes.Transparent;

        _mainText = new TextBlock
        {
            Foreground = _theme.Primary,
            FontFamily = new FontFamily("Segoe UI Variable Text"),
            FontSize = 11.5,
            FontWeight = FontWeights.SemiBold,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };
        _secondaryText = new TextBlock
        {
            Foreground = _theme.Secondary,
            FontFamily = new FontFamily("Segoe UI Variable Text"),
            FontSize = 10.5,
            TextTrimming = TextTrimming.CharacterEllipsis,
        };

        var text = new StackPanel
        {
            VerticalAlignment = VerticalAlignment.Center,
        };
        text.Children.Add(_mainText);
        text.Children.Add(_secondaryText);

        var ring = new Grid
        {
            Width = 28,
            Height = 28,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(4, 0, 8, 0),
        };
        ring.Children.Add(new Ellipse
        {
            Width = 24,
            Height = 24,
            Stroke = _theme.Track,
            StrokeThickness = 2,
        });
        _progressArc = new PathShape
        {
            Stroke = _focusAccent,
            StrokeThickness = 2.2,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
        };
        ring.Children.Add(_progressArc);
        _ringValue = new TextBlock
        {
            FontFamily = new FontFamily("Segoe UI Variable Text"),
            FontSize = 7.5,
            FontWeight = FontWeights.SemiBold,
            Foreground = _theme.Primary,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        ring.Children.Add(_ringValue);

        _toggleButton = TaskbarButton("\uE768", "Iniciar ou continuar");
        _toggleButton.Click += (_, eventArgs) =>
        {
            eventArgs.Handled = true;
            if (_snapshot.TimerState == "running") PausePomodoro();
            else if (_snapshot.TimerState is "paused" or "break") ResumePomodoro();
            else StartStudy(_snapshot.NextId, _snapshot.NextMinutes);
        };
        _phaseButton = TaskbarButton("\uE76C", "Ir para o descanso");
        _phaseButton.Click += (_, eventArgs) =>
        {
            eventArgs.Handled = true;
            if (_snapshot.TimerState == "break") ResumePomodoro();
            else StartPomodoroBreak();
        };
        var controls = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center,
            Margin = new Thickness(1, 0, 0, 0),
        };
        controls.Children.Add(_toggleButton);
        _phaseButton.Margin = new Thickness(3, 0, 0, 0);
        controls.Children.Add(_phaseButton);

        var layout = new DockPanel();
        DockPanel.SetDock(ring, Dock.Left);
        layout.Children.Add(ring);
        DockPanel.SetDock(controls, Dock.Right);
        layout.Children.Add(controls);
        layout.Children.Add(text);

        _surfaceBrush = new SolidColorBrush(Colors.Transparent);
        Content = new Border
        {
            CornerRadius = new CornerRadius(5),
            Background = _surfaceBrush,
            Padding = new Thickness(3, 2, 4, 2),
            Child = layout,
        };

        SourceInitialized += OnSourceInitialized;
        MouseEnter += (_, _) => AnimateSurface(_theme.TaskbarHover.Color);
        MouseLeave += (_, _) => AnimateSurface(Colors.Transparent);
        MouseLeftButtonDown += (_, _) => AnimateSurface(_theme.TaskbarPressed.Color, 55);
        MouseLeftButtonUp += (_, eventArgs) =>
        {
            if (!IsInsideButton(eventArgs.OriginalSource as DependencyObject)) ShowFlyout();
        };

        _positionTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(2) };
        _positionTimer.Tick += (_, _) => AttachAndPosition();
        _dataTimer = new DispatcherTimer { Interval = TimeSpan.FromSeconds(1) };
        _dataTimer.Tick += (_, _) => RefreshData();
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        _handle = new WindowInteropHelper(this).Handle;
        var style = NativeMethods.GetWindowLongPtr(_handle, NativeMethods.GwlStyle);
        NativeMethods.SetWindowLongPtr(
            _handle,
            NativeMethods.GwlStyle,
            (style & ~NativeMethods.WsPopup) | NativeMethods.WsChild);
        var extendedStyle = NativeMethods.GetWindowLongPtr(_handle, NativeMethods.GwlExStyle);
        NativeMethods.SetWindowLongPtr(
            _handle,
            NativeMethods.GwlExStyle,
            extendedStyle | NativeMethods.WsExToolWindow | NativeMethods.WsExNoActivate);

        RefreshData();
        AttachAndPosition();
        _positionTimer.Start();
        _dataTimer.Start();
    }

    private void AttachAndPosition()
    {
        if (_handle == 0) return;
        var taskbar = NativeMethods.FindWindow("Shell_TrayWnd", null);
        if (taskbar == 0 || !NativeMethods.GetWindowRect(taskbar, out var taskbarRect)) return;

        if (_taskbarHandle != taskbar || NativeMethods.GetParent(_handle) != taskbar)
        {
            _taskbarHandle = taskbar;
            NativeMethods.SetParent(_handle, taskbar);
        }

        var dpi = Math.Max(96u, NativeMethods.GetDpiForWindow(taskbar));
        var scale = dpi / 96.0;
        var width = (int)Math.Round(LogicalWidth * scale);
        var taskbarHeight = taskbarRect.Bottom - taskbarRect.Top;
        var height = Math.Min(taskbarHeight, (int)Math.Round(44 * scale));
        var x = taskbarRect.Right - taskbarRect.Left - width - (int)Math.Round(12 * scale);

        var tray = NativeMethods.FindWindowEx(taskbar, 0, "TrayNotifyWnd", null);
        if (tray != 0 && NativeMethods.GetWindowRect(tray, out var trayRect))
        {
            x = trayRect.Left - taskbarRect.Left - width - (int)Math.Round(8 * scale);
        }

        var y = Math.Max(0, (taskbarHeight - height) / 2);
        NativeMethods.SetWindowPos(
            _handle,
            NativeMethods.HwndTop,
            Math.Max(0, x),
            y,
            width,
            height,
            NativeMethods.SwpNoActivate | NativeMethods.SwpShowWindow);
    }

    private void RefreshData()
    {
        _snapshot = PlannerSnapshot.Read();
        _mainText.Text = _snapshot.HasSchedule
            ? _snapshot.TimerState is "break" or "running" or "paused"
                ? Clock(_snapshot.PhaseRemainingSeconds)
                : $"{Duration(_snapshot.TodaySeconds)} / {Duration(_snapshot.GoalMinutes * 60)}  ·  {_snapshot.Percent}%"
            : "Meu Rumo";
        _secondaryText.Text = _snapshot.HasSchedule
            ? $"{_snapshot.Completed}/{_snapshot.Total} tarefas"
            : "Sem cronograma ativo";
        _ringValue.Text = _snapshot.HasPomodoro
            ? Math.Max(0, (int)Math.Ceiling(_snapshot.PhaseRemainingSeconds / 60.0)).ToString()
            : _snapshot.HasSchedule ? _snapshot.Percent.ToString() : "—";
        _progressArc.Data = ProgressGeometry(_snapshot.PhasePercent);
        _progressArc.Stroke = _snapshot.TimerState == "break"
            ? _breakAccent
            : _focusAccent;
        _toggleButton.Content = _snapshot.TimerState == "running" ? "\uE769" : "\uE768";
        _toggleButton.ToolTip = _snapshot.TimerState == "running" ? "Pausar" : "Continuar";
        _phaseButton.ToolTip = _snapshot.TimerState == "break"
            ? "Voltar ao foco"
            : "Ir para o descanso";
        _phaseButton.IsEnabled = _snapshot.TimerState is "running" or "paused" or "break";
        _flyout?.Update(_snapshot);
    }

    internal void ShowFlyout()
    {
        RefreshData();
        if (_flyout is { IsVisible: true })
        {
            _flyout.Close();
            _flyout = null;
            return;
        }

        _flyout = new PlannerFlyoutWindow(
            _snapshot,
            StartStudy,
            OpenPlanner,
            PausePomodoro,
            StartPomodoroBreak,
            ResumePomodoro);
        _flyout.Closed += (_, _) => _flyout = null;
        PositionFlyout(_flyout);
        _flyout.Show();
        _flyout.Activate();
    }

    private void PositionFlyout(Window flyout)
    {
        var taskbar = NativeMethods.FindWindow("Shell_TrayWnd", null);
        if (taskbar == 0 || !NativeMethods.GetWindowRect(taskbar, out var rect)) return;
        var scale = Math.Max(96u, NativeMethods.GetDpiForWindow(taskbar)) / 96.0;
        flyout.Left = Math.Clamp(
            rect.Right / scale - flyout.Width - 18,
            SystemParameters.VirtualScreenLeft,
            SystemParameters.VirtualScreenLeft + SystemParameters.VirtualScreenWidth - flyout.Width);
        flyout.Top = rect.Top / scale > SystemParameters.VirtualScreenTop + 100
            ? rect.Top / scale - flyout.Height - 8
            : rect.Bottom / scale + 8;
    }

    private static void StartStudy(long activityId, int plannedMinutes)
    {
        var planner = System.IO.Path.GetFullPath(
            System.IO.Path.Combine(AppContext.BaseDirectory, "..", "study_planner.exe"));
        if (!File.Exists(planner)) return;
        Process.Start(new ProcessStartInfo(planner)
        {
            UseShellExecute = true,
            Arguments = activityId > 0 ? $"--study={activityId}:{plannedMinutes}" : "",
        });
    }

    private static void OpenPlanner(string route)
    {
        var planner = System.IO.Path.GetFullPath(
            System.IO.Path.Combine(AppContext.BaseDirectory, "..", "study_planner.exe"));
        if (!File.Exists(planner)) return;
        Process.Start(new ProcessStartInfo(planner)
        {
            UseShellExecute = true,
            Arguments = $"--open=\"{route}\"",
        });
    }

    private void PausePomodoro()
    {
        PlannerSnapshot.PausePomodoro();
        RefreshData();
    }

    private void StartPomodoroBreak()
    {
        PlannerSnapshot.StartPomodoroBreak();
        RefreshData();
    }

    private void ResumePomodoro()
    {
        PlannerSnapshot.ResumePomodoro();
        RefreshData();
    }

    private static string Duration(int seconds) => $"{seconds / 3600}h{seconds % 3600 / 60:00}";

    private static string Clock(int seconds) =>
        $"{seconds / 60:00}:{seconds % 60:00}";

    private void AnimateSurface(Color color, int milliseconds = 90) =>
        _surfaceBrush.BeginAnimation(
            SolidColorBrush.ColorProperty,
            new ColorAnimation(color, TimeSpan.FromMilliseconds(milliseconds)));

    private Button TaskbarButton(string glyph, string tooltip)
    {
        var button = new Button
        {
            Content = glyph,
            Width = 27,
            Height = 27,
            FontFamily = new FontFamily("Segoe Fluent Icons"),
            FontSize = 12,
            Foreground = _theme.Primary,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            ToolTip = tooltip,
            Cursor = Cursors.Hand,
            FocusVisualStyle = null,
        };
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(5));
        border.SetBinding(Border.BackgroundProperty, new System.Windows.Data.Binding(nameof(Background))
        {
            RelativeSource = new System.Windows.Data.RelativeSource(
                System.Windows.Data.RelativeSourceMode.TemplatedParent),
        });
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        presenter.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        border.AppendChild(presenter);
        button.Template = new ControlTemplate(typeof(Button)) { VisualTree = border };
        button.MouseEnter += (_, _) => button.Background = _theme.TaskbarHover;
        button.MouseLeave += (_, _) => button.Background = Brushes.Transparent;
        button.PreviewMouseLeftButtonDown += (_, _) => button.Background = _theme.TaskbarPressed;
        button.PreviewMouseLeftButtonUp += (_, _) => button.Background = _theme.TaskbarHover;
        return button;
    }

    private static bool IsInsideButton(DependencyObject? source)
    {
        for (var current = source; current is not null; current = VisualTreeHelper.GetParent(current))
        {
            if (current is Button) return true;
        }
        return false;
    }

    private static Geometry? ProgressGeometry(int percent)
    {
        if (percent <= 0) return null;
        const double center = 14;
        const double radius = 12;
        var angle = Math.Min(359.8, percent * 3.6);
        var radians = (angle - 90) * Math.PI / 180;
        var end = new Point(
            center + radius * Math.Cos(radians),
            center + radius * Math.Sin(radians));
        var figure = new PathFigure
        {
            StartPoint = new Point(center, center - radius),
            IsClosed = false,
        };
        figure.Segments.Add(new ArcSegment
        {
            Point = end,
            Size = new Size(radius, radius),
            SweepDirection = SweepDirection.Clockwise,
            IsLargeArc = angle > 180,
        });
        return new PathGeometry([figure]);
    }
}
