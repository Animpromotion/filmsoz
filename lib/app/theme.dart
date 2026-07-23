import 'package:flutter/material.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF1E1E1E),
    colorScheme: const ColorScheme.dark(
      surface: Color(0xFF252526),
      primary: Color(0xFF0E639C),
      secondary: Color(0xFF37373D),
      onSurface: Color(0xFFCCCCCC),
    ),
    fontFamily: 'Segoe UI',
    dividerTheme: const DividerThemeData(
      color: Color(0xFF2D2D2D),
      thickness: 1,
      space: 1,
    ),
  );
}
