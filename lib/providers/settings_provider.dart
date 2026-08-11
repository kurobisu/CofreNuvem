import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dashboard_user_limit') ?? 'Ilimitado';
  }

  Future<void> setLimit(String limit) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dashboard_user_limit', limit);
    state = AsyncData(limit);
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, String>(() {
  return SettingsNotifier();
});
