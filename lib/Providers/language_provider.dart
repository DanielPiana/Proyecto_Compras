import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Provider que gestiona el idioma de la aplicación
/// y persiste la preferencia del usuario en SharedPreferences
class LanguageProvider extends ChangeNotifier {
  Locale _locale = const Locale('es');

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLocale();
  }

  /// Carga el idioma guardado desde SharedPreferences al iniciar
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    String? langCode = prefs.getString('language_code');
    if (langCode != null) {
      _locale = Locale(langCode);
      notifyListeners();
    }
  }

  /// Cambia el idioma de la aplicación y guarda la preferencia
  Future<void> setLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    notifyListeners();
  }
}
