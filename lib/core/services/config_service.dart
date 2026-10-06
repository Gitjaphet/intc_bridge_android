import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/printer_config.dart';

class ConfigService {
  static const String _key = 'printer_config';

  Future<PrinterConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_key);
    if (json == null) return const PrinterConfig();
    return PrinterConfig.fromJson(jsonDecode(json));
  }

  Future<void> save(PrinterConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(config.toJson()));
  }
}
