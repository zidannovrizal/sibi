import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigProvider extends ChangeNotifier {
  static const String _keyServerUrl = 'ngrok_server_url';
  static const String defaultServerUrl =
      'wss://dione-unbonneted-guy.ngrok-free.dev';
  static const String _keyUseRemote = 'use_remote_server';

  String _serverUrl = '';
  bool _isLoaded = false;
  bool _useRemote = true;

  String get serverUrl => _serverUrl;
  bool get hasServerUrl => _serverUrl.trim().isNotEmpty;
  bool get isLoaded => _isLoaded;
  bool get useRemote => _useRemote;

  ServerConfigProvider() {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_keyServerUrl);
      _serverUrl = (stored == null || stored.isEmpty) ? defaultServerUrl : stored;
      _useRemote = prefs.getBool(_keyUseRemote) ?? true;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> setServerUrl(String url) async {
    final trimmed = url.trim();
    final prefs = await SharedPreferences.getInstance();
    if (trimmed.isEmpty) {
      await prefs.remove(_keyServerUrl);
    } else {
      await prefs.setString(_keyServerUrl, trimmed);
    }
    _serverUrl = trimmed;
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyServerUrl, defaultServerUrl);
    _serverUrl = defaultServerUrl;
    notifyListeners();
  }

  Future<void> setUseRemote(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyUseRemote, value);
    _useRemote = value;
    notifyListeners();
  }
}
