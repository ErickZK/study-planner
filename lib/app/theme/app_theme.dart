import 'package:material_ui/material_ui.dart';

abstract final class AppTokens {
  static const background = Colors.white;
  static const ink = Color(0xFF242424);
  static const muted = Color(0xFF626262);
  static const border = Color(0xFFE4E4E4);
  static const hover = Color(0xFFF5F5F5);
  static const focus = Color(0xFF737373);
  static const error = Color(0xFF9B2828);
  static const small = 8.0;
  static const medium = 16.0;
  static const large = 24.0;
  static const radius = 8.0;
  static const borderWidth = 1.0;
  static const desktopBreakpoint = 840.0;
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: AppTokens.background,
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
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppTokens.radius),
    ),
  ),
  dividerTheme: const DividerThemeData(
    color: AppTokens.border,
    thickness: AppTokens.borderWidth,
  ),
);
