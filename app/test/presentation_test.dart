import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/controllers/settings_controller.dart';
import 'package:geubsik/models/app_settings.dart';
import 'package:geubsik/models/meal_snapshot.dart';
import 'package:geubsik/utils/korea_date.dart';
import 'package:geubsik/utils/meal_dates.dart';
import 'package:geubsik/utils/menu_formatter.dart';

import 'fixtures.dart';

class TestSettingsStorage implements SettingsStorage {
  String? raw;
  bool fail = false;
  @override
  Future<String?> read() async => raw;
  @override
  Future<void> write(String data) async {
    if (fail) throw StateError('storage');
    raw = data;
  }
}

void main() {
  test('괄호·구분자·중첩·불완전한 문구와 특식 가공', () {
    expect(withoutParentheses('돼지국밥(돈삼겹:덴마크),(순대/돈육:국산)'), '돼지국밥');
    expect(withoutParentheses('닭구이(초등)(닭(살):국산)/국 & 밥*'), '닭구이/국 & 밥*');
    expect(withoutParentheses('국(미완 / 정상 메뉴(돈:국산)'), '국(미완 / 정상 메뉴');
    const raw = ['<특식(중등)>', '닭(국산)\n국(두부)', '밥'];
    final visible = MenuDisplay(raw, hideParentheses: true);
    expect(visible.preview.map((l) => l.text), ['<특식(중등)>', '닭', '국']);
    expect(visible.preview.first.special, isTrue);
    expect(visible.hasMore, isTrue);
    expect(visible.full.last.text, '밥');
    expect(
      MenuDisplay(
        raw,
        hideParentheses: false,
      ).full.map((l) => l.text).join('\n'),
      raw.join('\n'),
    );
    for (final hide in [true, false]) {
      final display = MenuDisplay([
        '<특식>',
        '중복(국산)\n두 번째 줄',
        '중복(국산)',
      ], hideParentheses: hide);
      expect(display.full.map((line) => line.representative), [
        false,
        true,
        true,
        false,
      ]);
      expect(display.preview, display.full.take(3));
    }
    expect(raw[1], '닭(국산)\n국(두부)');
  });

  test('설정 기본값, 보관·복원·초기화 및 캐시 독립성', () async {
    final cache = MemoryCache(document());
    final storage = TestSettingsStorage();
    final prefs = SettingsController(storage);
    await prefs.restore();
    const defaults = AppSettings();
    expect(prefs.value.encode(), defaults.encode());
    final first = prefs.set(
      defaults.copyWith(theme: ThemeMode.dark, background: Backdrop.green),
    );
    final next = prefs.set(
      prefs.value.copyWith(
        meals: {MealKind.lunch},
        period: SchedulePeriod.month,
        representative: true,
        hideParentheses: false,
        hideEmpty: true,
      ),
    );
    await Future.wait([first, next]);
    final loaded = SettingsController(storage);
    await loaded.restore();
    expect(loaded.value.encode(), prefs.value.encode());
    expect(loaded.value.copyWith(meals: {}).meals, {MealKind.lunch});
    await loaded.set(defaults);
    expect(storage.raw, defaults.encode());
    expect(cache.value, document());
  });

  test('오래되거나 잘못된 설정 복구, 저장 실패 시 화면 상태 보존', () async {
    for (final raw in [
      '{',
      '{"version":2}',
      '{"version":1,"meals":[],"theme":"unknown","hideEmpty":1}',
    ]) {
      expect(AppSettings.decode(raw).encode(), const AppSettings().encode());
    }
    final prefs = SettingsController(TestSettingsStorage()..fail = true);
    await prefs.set(const AppSettings(theme: ThemeMode.dark));
    expect(prefs.value.theme, ThemeMode.dark);
    expect(prefs.saveFailed, isTrue);
  });

  test('달력 활성 날짜, 등록 범위와 오늘 예외', () {
    final today = KoreaDate.parse('2026-12-07');
    final data = MealSnapshot.parse(
      document(meals: {'2026-11-26': day, '2026-11-27': emptyDay}),
    );
    final range = bounds(data, today);
    expect(range.first.key, '2026-11-26');
    expect(range.last, today);
    expect(selectable(range.first, today, data), isTrue);
    expect(selectable(range.first.next, today, data), isFalse);
    expect(selectable(range.first.next.next, today, data), isFalse);
    expect(selectable(today, today, data), isTrue);
    expect(bounds(MealSnapshot.parse(document(meals: {})), today).first, today);
  });

  test('6개 기간 및 선택 식사에 따른 빈 날짜 숨김', () {
    final today = KoreaDate.parse('2024-02-29');
    final data = MealSnapshot.parse(
      document(meals: {today.key: day, today.next.key: emptyDay}),
    );
    List<KoreaDate> forPeriod(SchedulePeriod p) =>
        scheduleDates(data, today, AppSettings(period: p));
    expect(forPeriod(SchedulePeriod.five).last.key, '2024-03-04');
    expect(forPeriod(SchedulePeriod.seven).length, 7);
    expect(forPeriod(SchedulePeriod.week).first.key, '2024-02-26');
    expect(forPeriod(SchedulePeriod.nextWeek).last.key, '2024-03-10');
    expect(forPeriod(SchedulePeriod.month).length, 29);
    expect(forPeriod(SchedulePeriod.all), [today, today.next]);
    expect(
      scheduleDates(
        data,
        today,
        const AppSettings(hideEmpty: true, meals: {MealKind.lunch}),
      ),
      [today],
    );
    expect(
      scheduleDates(
        data,
        today,
        const AppSettings(hideEmpty: true, meals: {MealKind.breakfast}),
      ),
      isEmpty,
    );
    expect(selectable(today, today.previous, data), isTrue);
    expect(updateLabel(stamp), '11월 26일 오전 12:29');
  });
}
