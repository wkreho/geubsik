import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

class SettingsStorage {
  static const key = 'geubsik.settings.v1';

  Future<String?> read() => SharedPreferencesAsync().getString(key);
  Future<void> write(String data) =>
      SharedPreferencesAsync().setString(key, data);
}

class SettingsController extends ChangeNotifier {
  SettingsController(this.storage);
  final SettingsStorage storage;
  AppSettings value = const AppSettings();
  bool saveFailed = false;
  Future<void> _writes = Future.value();
  bool _disposed = false;

  Future<void> restore() async {
    try {
      value = AppSettings.decode(await storage.read());
    } catch (_) {
      value = const AppSettings();
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> set(AppSettings next) {
    value = next;
    saveFailed = false;
    notifyListeners();
    // Serialize writes so rapid changes cannot restore an older preference.
    return _writes = _writes.then((_) async {
      var failed = false;
      try {
        await storage.write(next.encode());
      } catch (_) {
        failed = true;
      }
      if (!_disposed && identical(next, value) && failed) {
        saveFailed = true;
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
