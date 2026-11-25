import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/controllers/meal_controller.dart';
import 'package:geubsik/repositories/meal_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures.dart';

void main() {
  test('캐시 즉시 표시, 중복 요청 병합, 날짜 삭제와 전체 교체', () async {
    final started = Completer<void>();
    final response = Completer<http.Response>();
    var count = 0;
    final cache = MemoryCache(document(meals: {'2026-11-01': emptyDay}));
    final repo = MealRepository(
      MockClient((_) {
        count++;
        started.complete();
        return response.future;
      }),
    );
    final c = MealController(repo, cache);
    final first = c.refresh();
    await started.future;
    expect(c.source, MealSource.cache);
    expect(c.status, MealStatus.refreshing);
    expect(c.snapshot!.firstDate, '2026-11-01');
    expect(identical(first, c.refresh(manual: true)), isTrue);
    response.complete(ok(document()));
    await first;
    expect(count, 1);
    expect(c.snapshot!.dates, ['2026-11-26']);
    expect(c.source, MealSource.remote);
    expect(c.status, MealStatus.ready);
    expect(cache.value, document());
  });

  test('연결 오류 및 잘못된 원격 응답에서 정상 캐시 보존', () async {
    for (final invalidJson in [false, true]) {
      final cache = MemoryCache(document());
      final repo = MealRepository(
        MockClient((_) async {
          if (invalidJson) return ok('{');
          throw http.ClientException('offline');
        }),
      );
      final c = MealController(repo, cache);
      await c.refresh();
      expect(c.status, MealStatus.stale);
      expect(c.source, MealSource.cache);
      expect(c.snapshot!.dates, ['2026-11-26']);
      expect(cache.value, document());
    }
  });

  test('손상된 캐시와 원격 오류 후 다시 시도, 유효한 빈 스냅샷 반영', () async {
    final cache = MemoryCache('broken');
    var status = 503;
    final c = MealController(
      MealRepository(
        MockClient(
          (_) async => status == 200
              ? ok(document(meals: {}))
              : http.Response('', status),
        ),
      ),
      cache,
    );
    await c.refresh();
    expect(c.status, MealStatus.failed);
    expect(c.snapshot, isNull);
    status = 200;
    await c.refresh(manual: true);
    expect(c.status, MealStatus.ready);
    expect(cache.value, document(meals: {}));
  });

  test('정상 캐시도 전체 빈 응답으로 교체', () async {
    final cache = MemoryCache(document());
    final c = MealController(
      MealRepository(MockClient((_) async => ok(document(meals: {})))),
      cache,
    );
    await c.refresh();
    expect(c.snapshot!.dates, isEmpty);
    expect(cache.value, document(meals: {}));
  });

  test('캐시 읽기와 쓰기가 실패해도 받은 데이터를 표시', () async {
    final cache = MemoryCache()
      ..readFails = true
      ..writeFails = true;
    final c = MealController(
      MealRepository(MockClient((_) async => ok(document()))),
      cache,
    );
    expect(c.status, MealStatus.loading);
    await c.refresh();
    expect(c.status, MealStatus.ready);
    expect(c.source, MealSource.remote);
    expect(c.snapshot!.updatedAt, stamp);
    expect(c.message, contains('저장'));
  });
}
