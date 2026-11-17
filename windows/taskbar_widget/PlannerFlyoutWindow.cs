using System.Globalization;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Data;
using System.Windows.Interop;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Windows.Media.Effects;
using System.Windows.Media.Imaging;
using System.Windows.Shapes;
using System.Windows.Threading;
using PathShape = System.Windows.Shapes.Path;

namespace TJSP.Planner.TaskbarWidget;

internal sealed class PlannerFlyoutWindow : Window
{
    private readonly WidgetTheme _theme;
    private readonly SolidColorBrush _pomodoroAccent;
    private readonly SolidColorBrush _phaseAccent;
    private readonly bool _previewMode;
    private readonly Action<long, int> _startStudy;
    private readonly Action<string> _openPlanner;
    private readonly Action _pausePomodoro;
    private readonly Action _startPomodoroBreak;
    private readonly Action _resumePomodoro;
    private readonly TextBlock _project;
    private readonly TextBlock _session;
    private readonly TextBlock _phase;
    private readonly TextBlock _clock;
    private readonly TextBlock _state;
    private readonly TextBlock _focusToday;
    private readonly TextBlock _pomodorosToday;
    private readonly TextBlock _tasksToday;
    private readonly TextBlock _taskSummary;
    private readonly PathShape _phaseArc;
    private readonly StackPanel _cycleDots;
    private readonly Button _primaryButton;
    private readonly Button _stopButton;
    private readonly Button _breakButton;
    private readonly Button _nextButton;
    private readonly UIElement _pomodoroSurface;
    private BitmapSource? _backdrop;
    private PlannerSnapshot _snapshot;
    private bool _canAutoClose;
    private bool _showingStatistics;

    internal PlannerFlyoutWindow(
        PlannerSnapshot snapshot,
        Action<long, int> startStudy,
        Action<string> openPlanner,
        Action pausePomodoro,
        Action startPomodoroBreak,
        Action resumePomodoro,
        bool previewMode = false)
    {
        _snapshot = snapshot;
        _startStudy = startStudy;
        _openPlanner = openPlanner;
        _pausePomodoro = pausePomodoro;
        _startPomodoroBreak = startPomodoroBreak;
        _resumePomodoro = resumePomodoro;
        _previewMode = previewMode;
        _theme = WidgetTheme.Current;
        _pomodoroAccent = new SolidColorBrush(Color.FromRgb(255, 107, 97));
        _phaseAccent = new SolidColorBrush(Color.FromRgb(255, 98, 95));

        Width = 430;
        Height = 636;
        Title = "TJSP Planner — painel Pomodoro";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        ShowInTaskbar = previewMode;
        Topmost = !previewMode;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        Opacity = 0;

        _project = Text(18, _theme.Primary, FontWeights.SemiBold);
        _session = Text(11.5, _theme.Secondary, FontWeights.Normal);
        _phase = Text(13, _phaseAccent, FontWeights.SemiBold);
        _clock = Text(48, _theme.Primary, FontWeights.Light);
        _state = Text(12, _theme.Secondary, FontWeights.Normal);
        _focusToday = Text(20, _theme.Primary, FontWeights.SemiBold);
        _pomodorosToday = Text(20, _theme.Primary, FontWeights.SemiBold);
        _tasksToday = Text(20, _theme.Primary, FontWeights.SemiBold);
        _taskSummary = Text(11, _theme.Secondary, FontWeights.Normal);

        _phaseArc = new PathShape
        {
            Stroke = _phaseAccent,
            StrokeThickness = 9,
            StrokeStartLineCap = PenLineCap.Round,
            StrokeEndLineCap = PenLineCap.Round,
        };
        _cycleDots = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
        };

        _stopButton = RoundButton("\uE71A", 44, false, "Parar e preservar o tempo");
        _stopButton.Click += (_, _) => _pausePomodoro();
        _primaryButton = RoundButton("\uE768", 64, true, "Iniciar ou pausar");
        _primaryButton.Click += (_, _) => TogglePomodoro();
        _breakButton = RoundButton("\uE893", 44, false, "Ir para o descanso");
        _breakButton.Click += (_, _) =>
        {
            if (_snapshot.TimerState == "break") _resumePomodoro();
            else _startPomodoroBreak();
        };
        _nextButton = RoundButton("\uE768", 32, false, "Abrir o próximo estudo");
        _nextButton.Click += (_, _) =>
        {
            _startStudy(_snapshot.NextId, _snapshot.NextMinutes);
            Close();
        };

        _pomodoroSurface = BuildSurface();
        Content = _pomodoroSurface;
        Loaded += OnLoaded;
        Deactivated += (_, _) =>
        {
            if (_canAutoClose && !_previewMode) Close();
        };
        PreviewKeyDown += (_, eventArgs) =>
        {
            if (eventArgs.Key == System.Windows.Input.Key.Escape) Close();
        };
        Update(snapshot);
    }

    private UIElement BuildSurface()
    {
        var content = new Grid { Margin = new Thickness(20, 17, 20, 16) };
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(48) });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(262) });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(30) });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(74) });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(124) });
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });

        var header = new DockPanel { LastChildFill = true };
        var settings = RoundButton("\uE713", 32, false, "Abrir configurações");
        settings.Click += (_, _) =>
        {
            _openPlanner("/settings");
            Close();
        };
        DockPanel.SetDock(settings, Dock.Right);
        header.Children.Add(settings);
        DockPanel.SetDock(_nextButton, Dock.Right);
        _nextButton.Margin = new Thickness(0, 0, 8, 0);
        header.Children.Add(_nextButton);
        var heading = new StackPanel();
        heading.Children.Add(_project);
        heading.Children.Add(_session);
        header.Children.Add(heading);
        Grid.SetRow(header, 0);
        content.Children.Add(header);

        var tabs = new Grid { Margin = new Thickness(0, 8, 0, 0) };
        for (var index = 0; index < 3; index++)
            tabs.ColumnDefinitions.Add(new ColumnDefinition());
        var activeTab = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
        activeTab.Children.Add(Text(13, _theme.Primary, FontWeights.SemiBold, "Pomodoro"));
        activeTab.Children.Add(new Border
        {
            Width = 18,
            Height = 3,
            CornerRadius = new CornerRadius(2),
            Background = _pomodoroAccent,
            Margin = new Thickness(0, 7, 0, 0),
        });
        Grid.SetColumn(activeTab, 0);
        tabs.Children.Add(activeTab);
        var planning = NavigationButton("Planejamento");
        planning.Click += (_, _) => OpenPlanner("/planner");
        Grid.SetColumn(planning, 1);
        tabs.Children.Add(planning);
        var statistics = NavigationButton("Estatísticas");
        statistics.Click += (_, _) => ShowStatistics();
        Grid.SetColumn(statistics, 2);
        tabs.Children.Add(statistics);
        Grid.SetRow(tabs, 1);
        content.Children.Add(tabs);

        var ring = new Grid
        {
            Width = 238,
            Height = 238,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        ring.Children.Add(new Ellipse
        {
            Width = 218,
            Height = 218,
            Stroke = _theme.Track,
            StrokeThickness = 9,
        });
        ring.Children.Add(_phaseArc);
        var ringText = new StackPanel
        {
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        _phase.HorizontalAlignment = HorizontalAlignment.Center;
        _clock.HorizontalAlignment = HorizontalAlignment.Center;
        _state.HorizontalAlignment = HorizontalAlignment.Center;
        ringText.Children.Add(_phase);
        ringText.Children.Add(_clock);
        ringText.Children.Add(_state);
        ring.Children.Add(ringText);
        Grid.SetRow(ring, 2);
        content.Children.Add(ring);

        Grid.SetRow(_cycleDots, 3);
        content.Children.Add(_cycleDots);

        var controls = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            HorizontalAlignment = HorizontalAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };
        _stopButton.Margin = new Thickness(0, 0, 24, 0);
        _breakButton.Margin = new Thickness(24, 0, 0, 0);
        controls.Children.Add(_stopButton);
        controls.Children.Add(_primaryButton);
        controls.Children.Add(_breakButton);
        Grid.SetRow(controls, 4);
        content.Children.Add(controls);

        var stats = new StackPanel();
        var statsHeader = new DockPanel();
        var openStats = NavigationButton("Ver métricas  ›");
        openStats.Click += (_, _) => ShowStatistics();
        DockPanel.SetDock(openStats, Dock.Right);
        statsHeader.Children.Add(openStats);
        statsHeader.Children.Add(Text(12.5, _theme.Primary, FontWeights.SemiBold, "Hoje"));
        stats.Children.Add(statsHeader);
        var statsGrid = new Grid { Margin = new Thickness(0, 14, 0, 0) };
        for (var index = 0; index < 3; index++)
            statsGrid.ColumnDefinitions.Add(new ColumnDefinition());
        statsGrid.Children.Add(Stat(0, _focusToday, "Tempo de foco"));
        statsGrid.Children.Add(Stat(1, _pomodorosToday, "Pomodoros"));
        statsGrid.Children.Add(Stat(2, _tasksToday, "Tarefas"));
        stats.Children.Add(statsGrid);
        var statsCard = Card(stats, 14);
        Grid.SetRow(statsCard, 5);
        content.Children.Add(statsCard);

        _taskSummary.HorizontalAlignment = HorizontalAlignment.Center;
        _taskSummary.Margin = new Thickness(0, 9, 0, 0);
        Grid.SetRow(_taskSummary, 6);
        content.Children.Add(_taskSummary);

        return new Border
        {
            CornerRadius = new CornerRadius(9),
            Background = _theme.FlyoutSurface,
            BorderBrush = _theme.Stroke,
            BorderThickness = new Thickness(1),
            Child = content,
        };
    }

    private UIElement BuildStatisticsSurface()
    {
        var content = new Grid { Margin = new Thickness(20, 17, 20, 16) };
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        content.RowDefinitions.Add(new RowDefinition { Height = new GridLength(48) });
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        content.RowDefinitions.Add(new RowDefinition { Height = GridLength.Auto });
        content.RowDefinitions.Add(new RowDefinition());

        var header = new DockPanel { LastChildFill = true };
        var settings = RoundButton("\uE713", 32, false, "Abrir configurações");
        settings.Click += (_, _) => OpenPlanner("/settings");
        DockPanel.SetDock(settings, Dock.Right);
        header.Children.Add(settings);
        var heading = new StackPanel();
        heading.Children.Add(Text(18, _theme.Primary, FontWeights.SemiBold, "Estatísticas"));
        heading.Children.Add(Text(11.5, _theme.Secondary, FontWeights.Normal, _snapshot.Project));
        header.Children.Add(heading);
        Grid.SetRow(header, 0);
        content.Children.Add(header);

        var tabs = new Grid { Margin = new Thickness(0, 8, 0, 0) };
        for (var index = 0; index < 3; index++) tabs.ColumnDefinitions.Add(new ColumnDefinition());
        var pomodoro = NavigationButton("Pomodoro");
        pomodoro.Click += (_, _) => ShowPomodoro();
        Grid.SetColumn(pomodoro, 0);
        tabs.Children.Add(pomodoro);
        var planning = NavigationButton("Planejamento");
        planning.Click += (_, _) => OpenPlanner("/planner");
        Grid.SetColumn(planning, 1);
        tabs.Children.Add(planning);
        var activeTab = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };
        activeTab.Children.Add(Text(13, _theme.Primary, FontWeights.SemiBold, "Estatísticas"));
        activeTab.Children.Add(new Border
        {
            Width = 18,
            Height = 3,
            CornerRadius = new CornerRadius(2),
            Background = _pomodoroAccent,
            Margin = new Thickness(0, 7, 0, 0),
        });
        Grid.SetColumn(activeTab, 2);
        tabs.Children.Add(activeTab);
        Grid.SetRow(tabs, 1);
        content.Children.Add(tabs);

        var goal = new StackPanel();
        var goalHeader = new DockPanel();
        var goalPercent = Text(13, _pomodoroAccent, FontWeights.SemiBold, $"{_snapshot.Percent}%");
        DockPanel.SetDock(goalPercent, Dock.Right);
        goalHeader.Children.Add(goalPercent);
        goalHeader.Children.Add(Text(13, _theme.Primary, FontWeights.SemiBold, "Meta de hoje"));
        goal.Children.Add(goalHeader);
        goal.Children.Add(Text(
            28,
            _theme.Primary,
            FontWeights.SemiBold,
            $"{DurationShort(_snapshot.TodaySeconds)} de {_snapshot.GoalMinutes / 60}h{_snapshot.GoalMinutes % 60:00}"));
        var track = new Grid { Height = 7, Margin = new Thickness(0, 12, 0, 0) };
        track.Children.Add(new Border { Background = _theme.Track, CornerRadius = new CornerRadius(4) });
        track.Children.Add(new Border
        {
            Width = 330 * _snapshot.Percent / 100.0,
            HorizontalAlignment = HorizontalAlignment.Left,
            Background = _pomodoroAccent,
            CornerRadius = new CornerRadius(4),
        });
        goal.Children.Add(track);
        var goalCard = Card(goal, 16);
        goalCard.Margin = new Thickness(0, 5, 0, 12);
        Grid.SetRow(goalCard, 2);
        content.Children.Add(goalCard);

        var metrics = new UniformGrid { Columns = 2, Rows = 3 };
        metrics.Children.Add(MetricTile("\uE823", "Esta semana", DurationShort(_snapshot.WeekSeconds)));
        metrics.Children.Add(MetricTile("\uE787", "Este mês", DurationShort(_snapshot.MonthSeconds)));
        metrics.Children.Add(MetricTile("\uE916", "Pomodoros hoje", _snapshot.CompletedPomodoros.ToString(CultureInfo.InvariantCulture)));
        metrics.Children.Add(MetricTile("\uE73E", "Tarefas hoje", $"{_snapshot.Completed}/{_snapshot.Total}"));
        metrics.Children.Add(MetricTile("\uE9D9", "Questões no mês", _snapshot.MonthQuestions.ToString(CultureInfo.InvariantCulture)));
        var accuracy = _snapshot.MonthQuestions == 0
            ? "—"
            : $"{Math.Round(_snapshot.MonthCorrect * 100.0 / _snapshot.MonthQuestions):0}%";
        metrics.Children.Add(MetricTile("\uE9D2", "Aproveitamento", accuracy));
        Grid.SetRow(metrics, 3);
        content.Children.Add(metrics);

        var footer = Text(
            11,
            _theme.Secondary,
            FontWeights.Normal,
            $"{_snapshot.StudyDays} dias com estudo neste mês · dados atualizados automaticamente");
        footer.HorizontalAlignment = HorizontalAlignment.Center;
        footer.VerticalAlignment = VerticalAlignment.Bottom;
        footer.Margin = new Thickness(0, 12, 0, 3);
        Grid.SetRow(footer, 4);
        content.Children.Add(footer);

        return new Border
        {
            CornerRadius = new CornerRadius(9),
            Background = _theme.FlyoutSurface,
            BorderBrush = _theme.Stroke,
            BorderThickness = new Thickness(1),
            Child = content,
        };
    }

    private Border MetricTile(string glyph, string label, string value)
    {
        var panel = new StackPanel();
        panel.Children.Add(Text(15, _pomodoroAccent, FontWeights.Normal, glyph));
        panel.Children[^1].SetValue(TextBlock.FontFamilyProperty, new FontFamily("Segoe Fluent Icons"));
        var metric = Text(22, _theme.Primary, FontWeights.SemiBold, value);
        metric.Margin = new Thickness(0, 7, 0, 1);
        panel.Children.Add(metric);
        panel.Children.Add(Text(10.5, _theme.Secondary, FontWeights.Normal, label));
        var tile = Card(panel, 14);
        tile.Margin = new Thickness(4);
        return tile;
    }

    private void ShowStatistics()
    {
        _showingStatistics = true;
        Content = ComposeBackdrop(BuildStatisticsSurface());
    }

    private void ShowPomodoro()
    {
        _showingStatistics = false;
        Detach(_pomodoroSurface);
        Content = ComposeBackdrop(_pomodoroSurface);
        Update(_snapshot);
    }

    private UIElement ComposeBackdrop(UIElement surface)
    {
        var layer = new Grid { ClipToBounds = true };
        if (_backdrop != null)
        {
            layer.Children.Add(new Image
            {
                Source = _backdrop,
                Stretch = Stretch.Fill,
                Margin = new Thickness(-24),
                Effect = new BlurEffect { Radius = 18, KernelType = KernelType.Gaussian },
            });
        }
        layer.Children.Add(surface);
        return layer;
    }

    private static void Detach(UIElement element)
    {
        if (VisualTreeHelper.GetParent(element) is Panel panel)
            panel.Children.Remove(element);
    }

    private BitmapSource? CaptureBackdrop()
    {
        var handle = new WindowInteropHelper(this).Handle;
        if (handle == 0 || !NativeMethods.GetWindowRect(handle, out var bounds)) return null;
        var width = Math.Max(1, bounds.Right - bounds.Left);
        var height = Math.Max(1, bounds.Bottom - bounds.Top);
        var screen = NativeMethods.GetDC(0);
        if (screen == 0) return null;
        var memory = NativeMethods.CreateCompatibleDC(screen);
        var bitmap = NativeMethods.CreateCompatibleBitmap(screen, width, height);
        if (memory == 0 || bitmap == 0)
        {
            if (bitmap != 0) NativeMethods.DeleteObject(bitmap);
            if (memory != 0) NativeMethods.DeleteDC(memory);
            NativeMethods.ReleaseDC(0, screen);
            return null;
        }
        var previous = NativeMethods.SelectObject(memory, bitmap);
        try
        {
            NativeMethods.BitBlt(
                memory,
                0,
                0,
                width,
                height,
                screen,
                bounds.Left,
                bounds.Top,
                NativeMethods.SrcCopy);
            var source = Imaging.CreateBitmapSourceFromHBitmap(
                bitmap,
                nint.Zero,
                Int32Rect.Empty,
                BitmapSizeOptions.FromEmptyOptions());
            source.Freeze();
            return source;
        }
        finally
        {
            NativeMethods.SelectObject(memory, previous);
            NativeMethods.DeleteObject(bitmap);
            NativeMethods.DeleteDC(memory);
            NativeMethods.ReleaseDC(0, screen);
        }
    }

    private UIElement Stat(int column, TextBlock value, string label)
    {
        var panel = new StackPanel();
        panel.Children.Add(value);
        panel.Children.Add(Text(10.5, _theme.Secondary, FontWeights.Normal, label));
        Grid.SetColumn(panel, column);
        return panel;
    }

    private void TogglePomodoro()
    {
        if (_snapshot.TimerState == "running") _pausePomodoro();
        else if (_snapshot.TimerState is "paused" or "break") _resumePomodoro();
        else
        {
            _startStudy(_snapshot.NextId, _snapshot.NextMinutes);
            Close();
        }
    }

    private void OpenPlanner(string route)
    {
        _openPlanner(route);
        Close();
    }

    private void OnLoaded(object sender, RoutedEventArgs eventArgs)
    {
        var surface = Content as UIElement;
        _backdrop = CaptureBackdrop();
        if (surface != null)
        {
            Content = null;
            Content = ComposeBackdrop(surface);
        }
        var translate = new TranslateTransform(0, 10);
        if (Content is UIElement animatedSurface) animatedSurface.RenderTransform = translate;
        var ease = new CubicEase { EasingMode = EasingMode.EaseOut };
        BeginAnimation(
            OpacityProperty,
            new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(150)) { EasingFunction = ease });
        translate.BeginAnimation(
            TranslateTransform.YProperty,
            new DoubleAnimation(10, 0, TimeSpan.FromMilliseconds(190)) { EasingFunction = ease });
        var closeDelay = new DispatcherTimer { Interval = TimeSpan.FromMilliseconds(350) };
        closeDelay.Tick += (_, _) =>
        {
            closeDelay.Stop();
            _canAutoClose = true;
        };
        closeDelay.Start();
    }

    internal void Update(PlannerSnapshot snapshot)
    {
        _snapshot = snapshot;
        if (_showingStatistics)
        {
            Content = ComposeBackdrop(BuildStatisticsSurface());
            return;
        }
        _project.Text = snapshot.Project;
        _session.Text = snapshot.HasPomodoro
            ? $"Sessão {Math.Min(snapshot.CompletedPomodoros + 1, snapshot.PlannedPomodoros)} de {snapshot.PlannedPomodoros}"
            : "Pomodoro de estudos";
        _phase.Text = snapshot.TimerState == "break" ? "Descanso" : "Foco";
        _phaseAccent.Color = snapshot.TimerState == "break"
            ? Color.FromRgb(66, 194, 104)
            : Color.FromRgb(255, 98, 95);
        _clock.Text = snapshot.HasPomodoro
            ? ClockShort(snapshot.PhaseRemainingSeconds)
            : "25:00";
        _state.Text = snapshot.TimerState switch
        {
            "running" => "Em andamento",
            "paused" => "Pausado",
            "break" => "Pausa em andamento",
            _ => "Pronto para começar",
        };
        _phaseArc.Data = RingGeometry(snapshot.HasPomodoro ? snapshot.PhasePercent : 0);
        _primaryButton.Content = snapshot.TimerState == "running" ? "\uE769" : "\uE768";
        _primaryButton.ToolTip = snapshot.TimerState == "running" ? "Pausar" : "Continuar";
        _stopButton.IsEnabled = snapshot.TimerState == "running";
        _breakButton.IsEnabled = snapshot.TimerState is "running" or "paused" or "break";
        _breakButton.ToolTip = snapshot.TimerState == "break"
            ? "Pular o descanso e voltar ao foco"
            : "Ir para o descanso";
        _nextButton.ToolTip = snapshot.NextId > 0
            ? $"Próximo estudo: {snapshot.NextTitle}"
            : "Abrir o Planner";
        _focusToday.Text = DurationShort(snapshot.TodaySeconds);
        _pomodorosToday.Text = snapshot.CompletedPomodoros.ToString(CultureInfo.InvariantCulture);
        _tasksToday.Text = $"{snapshot.Completed}/{snapshot.Total}";
        _taskSummary.Text = snapshot.NextId > 0
            ? $"Próximo: {snapshot.NextTitle}"
            : $"{snapshot.Completed} de {snapshot.Total} tarefas concluídas hoje";
        UpdateDots(snapshot.CompletedPomodoros, snapshot.PlannedPomodoros);
    }

    private void UpdateDots(int completed, int planned)
    {
        _cycleDots.Children.Clear();
        var total = Math.Clamp(planned == 0 ? 4 : planned, 1, 6);
        for (var index = 0; index < total; index++)
        {
            _cycleDots.Children.Add(new Ellipse
            {
                Width = index == completed ? 9 : 7,
                Height = index == completed ? 9 : 7,
                Fill = index < completed || index == completed ? _pomodoroAccent : _theme.Track,
                Margin = new Thickness(4, 0, 4, 0),
            });
        }
    }

    private Border Card(UIElement child, double padding) => new()
    {
        Background = _theme.CardSurface,
        BorderBrush = _theme.Stroke,
        BorderThickness = new Thickness(1),
        CornerRadius = new CornerRadius(8),
        Padding = new Thickness(padding),
        Child = child,
    };

    private Button RoundButton(string glyph, double size, bool accent, string tooltip)
    {
        var button = new Button
        {
            Content = glyph,
            Width = size,
            Height = size,
            FontFamily = new FontFamily("Segoe Fluent Icons"),
            FontSize = accent ? 22 : 14,
            Foreground = accent ? Brushes.White : _theme.Primary,
            Background = accent ? _pomodoroAccent : _theme.CardSurface,
            BorderBrush = accent ? _pomodoroAccent : _theme.Stroke,
            BorderThickness = new Thickness(1),
            ToolTip = tooltip,
            Cursor = System.Windows.Input.Cursors.Hand,
            FocusVisualStyle = null,
        };
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(size / 2));
        border.SetBinding(Border.BackgroundProperty, new Binding(nameof(Background))
        {
            RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent),
        });
        border.SetBinding(Border.BorderBrushProperty, new Binding(nameof(BorderBrush))
        {
            RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent),
        });
        border.SetBinding(Border.BorderThicknessProperty, new Binding(nameof(BorderThickness))
        {
            RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent),
        });
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        presenter.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        border.AppendChild(presenter);
        button.Template = new ControlTemplate(typeof(Button)) { VisualTree = border };
        button.MouseEnter += (_, _) => button.Opacity = 0.84;
        button.MouseLeave += (_, _) => button.Opacity = 1;
        button.PreviewMouseLeftButtonDown += (_, _) => button.Opacity = 0.68;
        button.PreviewMouseLeftButtonUp += (_, _) => button.Opacity = 0.84;
        return button;
    }

    private Button NavigationButton(string label)
    {
        var button = new Button
        {
            Content = label,
            FontFamily = new FontFamily("Segoe UI Variable Text"),
            FontSize = 12,
            Foreground = _theme.Secondary,
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Cursor = System.Windows.Input.Cursors.Hand,
            FocusVisualStyle = null,
            Padding = new Thickness(6, 3, 6, 3),
        };
        var border = new FrameworkElementFactory(typeof(Border));
        border.SetValue(Border.CornerRadiusProperty, new CornerRadius(5));
        border.SetBinding(Border.BackgroundProperty, new Binding(nameof(Background))
        {
            RelativeSource = new RelativeSource(RelativeSourceMode.TemplatedParent),
        });
        var presenter = new FrameworkElementFactory(typeof(ContentPresenter));
        presenter.SetValue(HorizontalAlignmentProperty, HorizontalAlignment.Center);
        presenter.SetValue(VerticalAlignmentProperty, VerticalAlignment.Center);
        border.AppendChild(presenter);
        button.Template = new ControlTemplate(typeof(Button)) { VisualTree = border };
        button.MouseEnter += (_, _) => button.Background = _theme.CardHover;
        button.MouseLeave += (_, _) => button.Background = Brushes.Transparent;
        button.PreviewMouseLeftButtonDown += (_, _) => button.Background = _theme.CardSurface;
        button.PreviewMouseLeftButtonUp += (_, _) => button.Background = _theme.CardHover;
        return button;
    }

    private static Geometry? RingGeometry(int percent)
    {
        if (percent <= 0) return null;
        const double center = 119;
        const double radius = 109;
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

    private static TextBlock Text(
        double size,
        Brush color,
        FontWeight weight,
        string value = "") => new()
        {
            Text = value,
            FontFamily = new FontFamily("Segoe UI Variable Text"),
            FontSize = size,
            FontWeight = weight,
            Foreground = color,
            TextTrimming = TextTrimming.CharacterEllipsis,
            VerticalAlignment = VerticalAlignment.Center,
        };

    private static string ClockShort(int seconds) =>
        seconds >= 3600
            ? $"{seconds / 3600:00}:{seconds % 3600 / 60:00}:{seconds % 60:00}"
            : $"{seconds / 60:00}:{seconds % 60:00}";

    private static string DurationShort(int seconds) =>
        seconds >= 3600
            ? $"{seconds / 3600}h{seconds % 3600 / 60:00}"
            : $"{seconds / 60} min";
}
