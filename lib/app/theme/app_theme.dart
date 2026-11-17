import 'package:material_ui/material_ui.dart';

abstract final class AppTokens {
  static const background = Color(0xFFFCFCFD);
  static const ink = Color(0xFF111214);
  static const muted = Color(0xFF60636B);
  static const border = Color(0xFFE4E5E9);
  static const hover = Color(0xFFF3F3F5);
  static const focus = Color(0xFF4B5563);
  static const green = Color(0xFF20A23A);
  static const greenSoft = Color(0xFFE8F8EA);
  static const lavender = Color(0xFFF0EDFF);
  static const purple = Color(0xFF7C4DFF);
  static const blue = Color(0xFF2383E2);
  static const coral = Color(0xFFE85D75);
  static const orange = Color(0xFFE58A18);
  static const teal = Color(0xFF159A9C);
  static const redSoft = Color(0xFFFFE8E9);
  static const yellowSoft = Color(0xFFFFF2C9);
  static const blueSoft = Color(0xFFE1F2FF);
  static const cyanSoft = Color(0xFFDDF6FB);
  static const error = Color(0xFFC93434);
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const radius = 10.0;
  static const borderWidth = 1.0;
  static const desktopBreakpoint = 960.0;
  static const sidebarWidth = 242.0;
  static const pageMaxWidth = 1420.0;
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppTokens.background,
  fontFamily: 'Segoe UI',
  colorScheme: const ColorScheme.light(
    primary: AppTokens.ink,
    onPrimary: Colors.white,
    secondary: AppTokens.muted,
    surface: Colors.white,
    onSurface: AppTokens.ink,
    outline: AppTokens.border,
    error: AppTokens.error,
  ),
  hoverColor: AppTokens.hover,
  focusColor: AppTokens.focus.withValues(alpha: 0.18),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.8,
    ),
    headlineSmall: TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.6,
    ),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 14, height: 1.4),
    bodyMedium: TextStyle(fontSize: 13, height: 1.35),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radius),
      borderSide: const BorderSide(color: AppTokens.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radius),
      borderSide: const BorderSide(color: AppTokens.border),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppTokens.border,
    thickness: AppTokens.borderWidth,
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppTokens.radius)),
      side: BorderSide(color: AppTokens.border),
    ),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: AppTokens.ink,
      borderRadius: BorderRadius.circular(7),
    ),
    textStyle: const TextStyle(color: Colors.white, fontSize: 12),
  ),
  checkboxTheme: CheckboxThemeData(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
    side: const BorderSide(color: Color(0xFF9DA0A8), width: 1.2),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppTokens.ink,
      side: const BorderSide(color: AppTokens.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  ),
  segmentedButtonTheme: SegmentedButtonThemeData(
    style: ButtonStyle(
      visualDensity: VisualDensity.compact,
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
      side: const WidgetStatePropertyAll(BorderSide(color: AppTokens.border)),
    ),
  ),
);
