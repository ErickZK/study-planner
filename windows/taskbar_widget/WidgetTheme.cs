using Microsoft.Win32;
using System.Windows.Media;

namespace TJSP.Planner.TaskbarWidget;

internal sealed class WidgetTheme
{
    private WidgetTheme(bool dark)
    {
        IsDark = dark;
        Primary = Brush(dark ? 245 : 22, dark ? 245 : 22, dark ? 245 : 22);
        Secondary = Brush(dark ? 194 : 92, dark ? 198 : 92, dark ? 203 : 92);
        Tertiary = Brush(dark ? 154 : 112, dark ? 159 : 112, dark ? 166 : 112);
        // The flyout uses real per-pixel WPF transparency. Keep enough tint for
        // text contrast while allowing the desktop wallpaper to remain visible.
        FlyoutSurface = dark
            ? Brush(18, 18, 22, 176)
            : Brush(255, 255, 255, 204);
        CardSurface = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 9 : 6);
        CardHover = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 17 : 11);
        Stroke = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 14 : 12);
        Track = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 24 : 14);
        TaskbarHover = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 18 : 12);
        TaskbarPressed = Brush(dark ? 255 : 0, dark ? 255 : 0, dark ? 255 : 0, dark ? 28 : 20);
        Accent = SystemParametersAccent();
        AccentSoft = new SolidColorBrush(Color.FromArgb(35, Accent.Color.R, Accent.Color.G, Accent.Color.B));
    }

    internal bool IsDark { get; }
    internal SolidColorBrush Primary { get; }
    internal SolidColorBrush Secondary { get; }
    internal SolidColorBrush Tertiary { get; }
    internal SolidColorBrush FlyoutSurface { get; }
    internal SolidColorBrush CardSurface { get; }
    internal SolidColorBrush CardHover { get; }
    internal SolidColorBrush Stroke { get; }
    internal SolidColorBrush Track { get; }
    internal SolidColorBrush TaskbarHover { get; }
    internal SolidColorBrush TaskbarPressed { get; }
    internal SolidColorBrush Accent { get; }
    internal SolidColorBrush AccentSoft { get; }

    internal static WidgetTheme Current => new(IsSystemDark());

    private static bool IsSystemDark()
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(
                @"Software\Microsoft\Windows\CurrentVersion\Themes\Personalize");
            var fallback = key?.GetValue("AppsUseLightTheme", 0) ?? 0;
            return Convert.ToInt32(
                key?.GetValue("SystemUsesLightTheme", fallback) ?? fallback) == 0;
        }
        catch
        {
            return true;
        }
    }

    private static SolidColorBrush SystemParametersAccent()
    {
        var color = System.Windows.SystemParameters.WindowGlassColor;
        if (color.A == 0) color = Color.FromRgb(0, 120, 212);
        return new SolidColorBrush(Color.FromRgb(color.R, color.G, color.B));
    }

    private static SolidColorBrush Brush(int red, int green, int blue, int alpha = 255) =>
        new(Color.FromArgb((byte)alpha, (byte)red, (byte)green, (byte)blue));
}
