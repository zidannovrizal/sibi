import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _keyIsDark = 'is_dark_mode';

  bool _isDark = false;
  bool _loaded = false;

  bool get isDark => _isDark;
  bool get isLoaded => _loaded;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool(_keyIsDark) ?? false;
    _loaded = true;
    notifyListeners();
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = !_isDark;
    await prefs.setBool(_keyIsDark, _isDark);
    notifyListeners();
  }
}
