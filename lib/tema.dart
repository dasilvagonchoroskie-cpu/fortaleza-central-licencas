import 'package:flutter/material.dart';

/// Cores da Central (as mesmas da 2.x): verde-escuro com destaque verde.
const corFundo = Color(0xFF0A140D);
const corDestaque = Color(0xFF4ADE80);
const corAviso = Color(0xFFFBBF24);
const corPerigo = Color(0xFFF87171);
const corInfo = Color(0xFF7FB8D9);

ThemeData temaCentral() {
  final esquema = ColorScheme.fromSeed(seedColor: const Color(0xFF22C55E), brightness: Brightness.dark).copyWith(
    primary: corDestaque,
    onPrimary: const Color(0xFF07160D),
    surface: corFundo,
    error: corPerigo,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: corFundo,
    appBarTheme: const AppBarThemeData(backgroundColor: corFundo, scrolledUnderElevation: 0, centerTitle: false),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: const Color(0xFF0F1F15),
      indicatorColor: corDestaque.withValues(alpha: 0.22),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
