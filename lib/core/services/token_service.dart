import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Jeton du pont : généré une seule fois, mémorisé sur le téléphone,
/// collé dans Odoo à la première impression (même contrat que le pont PC v0.1.2).
class TokenService {
  static const _key = 'bridge_token';
  static String? _cache;

  static Future<String> load() async {
    if (_cache != null) return _cache!;
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_key);
    if (token == null || token.isEmpty) {
      final rnd = Random.secure();
      token = base64UrlEncode(List<int>.generate(24, (_) => rnd.nextInt(256)))
          .replaceAll('=', '');
      await prefs.setString(_key, token);
    }
    return _cache = token;
  }

  /// Comparaison en temps constant : empêche de deviner le jeton au chronomètre.
  static bool matches(String sent, String expected) {
    if (sent.length != expected.length) return false;
    var diff = 0;
    for (var i = 0; i < sent.length; i++) {
      diff |= sent.codeUnitAt(i) ^ expected.codeUnitAt(i);
    }
    return diff == 0;
  }
}
