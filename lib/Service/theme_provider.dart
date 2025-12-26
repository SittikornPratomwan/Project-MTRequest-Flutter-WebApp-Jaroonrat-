import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static bool _isDark = false;
  static bool get isDarkMode => _isDark;

  static final List<VoidCallback> _listeners = [];

  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  // Helper to toggle theme for testing/demo
  static void toggleTheme() {
    _isDark = !_isDark;
    for (final l in List<VoidCallback>.from(_listeners)) {
      try {
        l();
      } catch (_) {}
    }
  }
}
