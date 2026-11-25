import 'package:shared_preferences/shared_preferences.dart';

class MealCache {
  static const _key = 'geubsik.mealSnapshot.v1';

  Future<String?> read() => SharedPreferencesAsync().getString(_key);
  Future<void> write(String source) =>
      SharedPreferencesAsync().setString(_key, source);
}
