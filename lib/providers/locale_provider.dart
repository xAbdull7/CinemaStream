import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/app_strings.dart';

class LocaleProvider extends ChangeNotifier {
  String _languageCode = 'en'; // English by default

  String get languageCode => _languageCode;
  bool get isArabic => _languageCode == 'ar';

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    _languageCode = prefs.getString('language_code') ?? 'en';
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', code);
    notifyListeners();
  }

  String tr(String key, {Map<String, String>? params}) {
    return AppStrings.get(key, _languageCode, params: params);
  }
}

