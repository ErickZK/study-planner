using System.Runtime.InteropServices;
using System.Windows.Interop;
using System.Windows.Media;

namespace TJSP.Planner.TaskbarWidget;

internal static class NativeWindowEffects
{
    private const int DwmwaUseImmersiveDarkMode = 20;
    private const int DwmwaWindowCornerPreference = 33;
    private const int DwmwaSystemBackdropType = 38;
    private const int DwmwaRedirectionBitmapAlpha = 39;
    private const int RoundCorners = 2;
    private const int TransientBackdrop = 3;

    internal static unsafe void ApplyAcrylic(nint handle, bool dark)
    {
        // AABBGGRR: keep a restrained tint while the compositor blurs details
        // behind the real per-pixel transparent WPF window.
        var policy = new NativeMethods.AccentPolicy
        {
            State = NativeMethods.AccentState.BlurBehind,
            Flags = 0,
            GradientColor = 0,
        };
        var data = new NativeMethods.WindowCompositionAttributeData
        {
            Attribute = NativeMethods.WindowCompositionAttribute.AccentPolicy,
            Data = (nint)(&policy),
            Size = sizeof(NativeMethods.AccentPolicy),
        };
        NativeMethods.SetWindowCompositionAttribute(handle, ref data);
    }

    internal static void ApplyFlyout(nint handle, bool dark)
    {
        // WPF otherwise paints an opaque black composition target before DWM
        // applies the backdrop. A transparent target lets Desktop Acrylic show
        // the wallpaper, matching the Windows taskbar material.
        if (HwndSource.FromHwnd(handle) is { CompositionTarget: not null } source)
            source.CompositionTarget.BackgroundColor = Colors.Transparent;
        var darkMode = dark ? 1 : 0;
        var corners = RoundCorners;
        var backdrop = TransientBackdrop;
        var useRedirectionAlpha = 1;
        NativeMethods.DwmSetWindowAttribute(handle, DwmwaUseImmersiveDarkMode, ref darkMode, sizeof(int));
        NativeMethods.DwmSetWindowAttribute(handle, DwmwaWindowCornerPreference, ref corners, sizeof(int));
        NativeMethods.DwmSetWindowAttribute(handle, DwmwaSystemBackdropType, ref backdrop, sizeof(int));
        NativeMethods.DwmSetWindowAttribute(
            handle,
            DwmwaRedirectionBitmapAlpha,
            ref useRedirectionAlpha,
            sizeof(int));
        var margins = new NativeMethods.Margins { Left = -1, Right = -1, Top = -1, Bottom = -1 };
        NativeMethods.DwmExtendFrameIntoClientArea(handle, ref margins);
    }
}
