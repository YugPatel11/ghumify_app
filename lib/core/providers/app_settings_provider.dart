import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

/// App-wide settings provider (theme, language)
class AppSettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  String _language = AppConstants.defaultLanguage;
  String _foodPreference = 'all';
  bool _isFirstLaunch = true;

  ThemeMode get themeMode => _themeMode;
  String get language => _language;
  String get foodPreference => _foodPreference;
  bool get isFirstLaunch => _isFirstLaunch;

  AppSettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final themeIndex = prefs.getInt('themeMode') ?? 0;
    _themeMode = ThemeMode.values[themeIndex];
    _language = prefs.getString('language') ?? AppConstants.defaultLanguage;
    _foodPreference = prefs.getString('foodPreference') ?? 'all';
    _isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeMode', mode.index);
    notifyListeners();
  }

  Future<void> setLanguage(String languageCode) async {
    _language = languageCode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language', languageCode);
    notifyListeners();
  }

  Future<void> setFoodPreference(String preference) async {
    _foodPreference = preference;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('foodPreference', preference);
    notifyListeners();
  }

  Future<void> setFirstLaunchDone() async {
    _isFirstLaunch = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isFirstLaunch', false);
    notifyListeners();
  }
}
