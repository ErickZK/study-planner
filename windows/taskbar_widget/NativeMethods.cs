using System.Runtime.InteropServices;

namespace TJSP.Planner.TaskbarWidget;

internal static partial class NativeMethods
{
    internal const int GwlStyle = -16;
    internal const int GwlExStyle = -20;
    internal const nint WsChild = 0x40000000;
    internal const nint WsPopup = unchecked((int)0x80000000);
    internal const nint WsExToolWindow = 0x00000080;
    internal const nint WsExNoActivate = 0x08000000;
    internal const uint SwpNoActivate = 0x0010;
    internal const uint SwpShowWindow = 0x0040;
    internal const uint SrcCopy = 0x00CC0020;
    internal static readonly nint HwndTop = 0;

    internal enum WindowCompositionAttribute
    {
        AccentPolicy = 19,
    }

    internal enum AccentState
    {
        Disabled = 0,
        BlurBehind = 3,
        AcrylicBlurBehind = 4,
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct AccentPolicy
    {
        internal AccentState State;
        internal int Flags;
        internal int GradientColor;
        internal int AnimationId;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct WindowCompositionAttributeData
    {
        internal WindowCompositionAttribute Attribute;
        internal nint Data;
        internal int Size;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Rect
    {
        internal int Left;
        internal int Top;
        internal int Right;
        internal int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct Margins
    {
        internal int Left;
        internal int Right;
        internal int Top;
        internal int Bottom;
    }

    [LibraryImport("user32.dll", EntryPoint = "FindWindowW", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial nint FindWindow(string className, string? windowName);

    [LibraryImport("user32.dll", EntryPoint = "FindWindowExW", StringMarshalling = StringMarshalling.Utf16)]
    internal static partial nint FindWindowEx(nint parent, nint childAfter, string className, string? windowName);

    [LibraryImport("user32.dll")]
    internal static partial nint SetParent(nint child, nint parent);

    [LibraryImport("user32.dll")]
    internal static partial nint GetParent(nint child);

    [LibraryImport("user32.dll", EntryPoint = "GetWindowLongPtrW")]
    internal static partial nint GetWindowLongPtr(nint window, int index);

    [LibraryImport("user32.dll", EntryPoint = "SetWindowLongPtrW")]
    internal static partial nint SetWindowLongPtr(nint window, int index, nint value);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool GetWindowRect(nint window, out Rect rect);

    [LibraryImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool SetWindowPos(
        nint window,
        nint insertAfter,
        int x,
        int y,
        int width,
        int height,
        uint flags);

    [LibraryImport("user32.dll")]
    internal static partial uint GetDpiForWindow(nint window);

    [LibraryImport("user32.dll")]
    internal static partial nint GetDC(nint window);

    [LibraryImport("user32.dll")]
    internal static partial int ReleaseDC(nint window, nint deviceContext);

    [LibraryImport("gdi32.dll")]
    internal static partial nint CreateCompatibleDC(nint deviceContext);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool DeleteDC(nint deviceContext);

    [LibraryImport("gdi32.dll")]
    internal static partial nint CreateCompatibleBitmap(
        nint deviceContext,
        int width,
        int height);

    [LibraryImport("gdi32.dll")]
    internal static partial nint SelectObject(nint deviceContext, nint value);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool DeleteObject(nint value);

    [LibraryImport("gdi32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    internal static partial bool BitBlt(
        nint destination,
        int destinationX,
        int destinationY,
        int width,
        int height,
        nint source,
        int sourceX,
        int sourceY,
        uint operation);

    [LibraryImport("user32.dll")]
    internal static partial int SetWindowCompositionAttribute(
        nint window,
        ref WindowCompositionAttributeData data);

    [LibraryImport("dwmapi.dll")]
    internal static partial int DwmSetWindowAttribute(
        nint window,
        int attribute,
        ref int value,
        int valueSize);

    [LibraryImport("dwmapi.dll")]
    internal static partial int DwmExtendFrameIntoClientArea(nint window, ref Margins margins);
}
