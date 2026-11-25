import 'dart:convert';
import 'package:geubsik/services/meal_cache.dart';
import 'package:http/http.dart' as http;

const stamp = '2026-11-26T00:29:45.027097+09:00';
const menu = '<특식>\n닭구이(닭:국산)';
const day = {
  'breakfast': <String>[],
  'lunch': [menu],
  'dinner': <String>[],
};
const emptyDay = {
  'breakfast': <String>[],
  'lunch': <String>[],
  'dinner': <String>[],
};

String document({
  Object? version = 1,
  Object? updatedAt = stamp,
  Object? meals = const {'2026-11-26': day},
}) => jsonEncode({
  'schemaVersion': version,
  'updatedAt': updatedAt,
  'meals': meals,
});

http.Response ok(String body) => http.Response.bytes(utf8.encode(body), 200);

class MemoryCache implements MealCache {
  MemoryCache([this.value]);
  String? value;
  bool readFails = false;
  bool writeFails = false;

  @override
  Future<String?> read() async {
    if (readFails) throw StateError('read failed');
    return value;
  }

  @override
  Future<void> write(String source) async {
    if (writeFails) throw StateError('write failed');
    value = source;
  }
}
