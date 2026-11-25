import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/models/meal_snapshot.dart';
import 'package:geubsik/utils/korea_date.dart';
import 'fixtures.dart';

void main() {
  test('한국 자정과 같은 순간의 다른 시간대 표기', () {
    final before = DateTime.parse('2026-11-25T14:59:59.999Z');
    final midnight = DateTime.parse('2026-11-25T10:00:00-05:00');
    expect(KoreaDate.today(before).key, '2026-11-25');
    expect(KoreaDate.today(midnight).key, '2026-11-26');
    expect(KoreaDate.parse('2026-11-26').isToday(midnight), isTrue);
  });

  test('월말·윤년·연말과 양 끝을 포함하는 달력 범위', () {
    final leap = KoreaDate.parse('2024-02-29');
    expect(leap.next.previous, leap);
    expect(leap.previous.through(leap.next).map((d) => d.key), [
      '2024-02-28',
      '2024-02-29',
      '2024-03-01',
    ]);
    expect(KoreaDate.parse('2026-01-01').previous.key, '2025-12-31');
    expect(KoreaDate.parse('2026-02-28').next.key, '2026-03-01');
  });

  test('원문과 변경 시각 보존, 정렬, 누락 날짜 및 빈 식사 구분', () {
    final data = MealSnapshot.parse(
      document(
        meals: {'2026-11-27': emptyDay, '2026-11-25': day, '2026-11-26': day},
      ),
    );
    expect(data.schemaVersion, 1);
    expect(data.updatedAt, stamp);
    expect(data.dates, ['2026-11-25', '2026-11-26', '2026-11-27']);
    expect(data.firstDate, data.dates.first);
    expect(data.lastDate, data.dates.last);
    final start = KoreaDate.parse('2026-11-26');
    expect(data.inRange(start, start.next).keys, ['2026-11-26', '2026-11-27']);
    expect(data.today(DateTime.utc(2026, 11, 25, 15))!.lunch, [menu]);
    expect(data.forDate(start.next)!.lunch, isEmpty);
    expect(data.forDate(start.next.next), isNull);
    final empty = MealSnapshot.parse(document(meals: {}));
    expect(empty.firstDate, isNull);
    expect(empty.lastDate, isNull);
  });

  test('잘못된 JSON, 버전, 필드, 자료형, 날짜와 변경 시각 거부', () {
    for (final source in [
      '{',
      '[]',
      '{}',
      document(version: 2),
      document(version: '1'),
      document(meals: []),
      document(meals: {'2026-11-26': 1}),
      document(
        meals: {
          '2026-11-26': {'breakfast': [], 'lunch': []},
        },
      ),
      document(
        meals: {
          '2026-11-26': {...day, 'lunch': '국'},
        },
      ),
      document(
        meals: {
          '2026-11-26': {
            ...day,
            'dinner': [3],
          },
        },
      ),
      for (final key in ['2025-02-29', '2026-11-31', '26-1-2', '0000-01-01'])
        document(meals: {key: day}),
      for (final invalid in [
        null,
        '어제',
        '2026-02-30T00:00:00+09:00',
        '2026-11-26T24:00:00+09:00',
        '2026-11-26T12:00:00',
      ])
        document(updatedAt: invalid),
    ]) {
      expect(
        () => MealSnapshot.parse(source),
        throwsFormatException,
        reason: source,
      );
    }
  });
}
