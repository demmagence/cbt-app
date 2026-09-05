import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ExamDraftStore {
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();
  Future<Map<String, dynamic>?> read(String key) async {
    final text = await _preferences.getString('cbt.draft.$key');
    if (text == null) {
      return null;
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(text) as Map);
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String key, Map<String, dynamic> value) =>
      _preferences.setString('cbt.draft.$key', jsonEncode(value));
  Future<void> remove(String key) => _preferences.remove('cbt.draft.$key');
}
