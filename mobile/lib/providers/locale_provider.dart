import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Manages app locale with backend sync.
/// Locale is loaded from backend settings on app start and saved on change.
class LocaleProvider extends ChangeNotifier {
  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static const supportedLocales = [Locale('en'), Locale('fr'), Locale('it'), Locale('pt'), Locale('da'), Locale('ro')];

  /// Load locale from backend settings.
  Future<void> loadFromSettings(String serverUrl) async {
    if (serverUrl.isEmpty) return;

    try {
      final uri = Uri.tryParse(serverUrl);
      if (uri == null) return;
      final webhookUrl = 'http://${uri.host}:8889';

      final response = await http.get(Uri.parse('$webhookUrl/settings')).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final lang = data['settings']?['language'] ?? 'en';
        final newLocale = Locale(lang);
        if (supportedLocales.contains(newLocale) && newLocale != _locale) {
          _locale = newLocale;
          notifyListeners();
        }
      }
    } catch (e) {
      // Keep default locale on error
    }
  }

  /// Change locale and save to backend.
  Future<void> setLocale(Locale newLocale, String serverUrl) async {
    if (newLocale == _locale) return;
    if (!supportedLocales.contains(newLocale)) return;

    // Update local state first for immediate UI feedback
    _locale = newLocale;
    notifyListeners();

    // Save to backend
    if (serverUrl.isNotEmpty) {
      try {
        final uri = Uri.tryParse(serverUrl);
        if (uri == null) return;
        final webhookUrl = 'http://${uri.host}:8889';

        await http.post(
          Uri.parse('$webhookUrl/settings'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'settings': {'language': newLocale.languageCode}
          }),
        );
      } catch (e) {
        // Locale already updated locally, backend sync failed silently
      }
    }
  }
}
