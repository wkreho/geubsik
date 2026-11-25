import 'dart:collection';
import 'dart:convert';

import '../utils/korea_date.dart';
import 'daily_meals.dart';

class MealSnapshot {
  MealSnapshot._(this.schemaVersion, this.updatedAt, this.meals);

  final int schemaVersion;
  // Preserve the producer's offset and fractional seconds, including on Web.
  final String updatedAt;
  final Map<String, DailyMeals> meals;

  static final _timestamp = RegExp(
    r'^(\d{4}-\d{2}-\d{2})T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,6})?\+09:00$',
  );

  factory MealSnapshot.parse(String source) {
    final json = jsonDecode(source);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('급식 스냅샷 형식이 올바르지 않습니다.');
    }
    final version = json['schemaVersion'];
    if (version is! int || version != 1) {
      throw const FormatException('지원하지 않는 급식 스키마입니다.');
    }
    final stamp = json['updatedAt'];
    if (stamp is! String || !_timestamp.hasMatch(stamp)) {
      throw const FormatException('데이터 변경 시각이 올바르지 않습니다.');
    }
    KoreaDate.parse(stamp.substring(0, 10));

    final days = json['meals'];
    if (days is! Map<String, dynamic>) {
      throw const FormatException('날짜별 급식표가 필요합니다.');
    }
    final sorted = SplayTreeMap<String, DailyMeals>();
    for (final entry in days.entries) {
      KoreaDate.parse(entry.key);
      sorted[entry.key] = DailyMeals.fromJson(entry.value);
    }
    return MealSnapshot._(version, stamp, Map.unmodifiable(sorted));
  }

  DailyMeals? forDate(KoreaDate day) => meals[day.key];
  DailyMeals? today([DateTime? instant]) => forDate(KoreaDate.today(instant));
  List<String> get dates => List.unmodifiable(meals.keys);
  String? get firstDate => meals.keys.firstOrNull;
  String? get lastDate => meals.keys.lastOrNull;

  Map<String, DailyMeals> inRange(KoreaDate start, KoreaDate end) {
    final first = start.key;
    final last = end.key;
    return {
      for (final entry in meals.entries)
        if (entry.key.compareTo(first) >= 0 && entry.key.compareTo(last) <= 0)
          entry.key: entry.value,
    };
  }
}
