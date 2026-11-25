import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/repositories/meal_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures.dart';

void main() {
  test('UTF-8 GET 및 수동 새로고침 URL', () async {
    final urls = <Uri>[];
    final repo = MealRepository(
      MockClient((request) async {
        expect(request.method, 'GET');
        urls.add(request.url);
        return ok(document());
      }),
    );
    final result = await repo.fetch();
    expect(result.snapshot.meals.values.first.lunch, [menu]);
    await repo.fetch(manual: true);
    expect(urls.first, MealRepository.endpoint);
    expect(urls.last.path, urls.first.path);
    expect(urls.last.queryParameters, contains('refresh'));
  });

  test('HTTP 오류와 응답 시간 초과', () async {
    final repo = MealRepository(
      MockClient((_) async => http.Response('', 404)),
    );
    await expectLater(repo.fetch(), throwsA(isA<http.ClientException>()));
    final never = Completer<http.Response>();
    final slow = MealRepository(
      MockClient((_) => never.future),
      timeout: Duration.zero,
    );
    await expectLater(slow.fetch(), throwsA(isA<TimeoutException>()));
    never.complete(ok(document()));
  });

  test('잘못된 UTF-8, JSON 및 스키마 거부', () async {
    for (final response in [
      http.Response.bytes([0xff], 200),
      ok('<html>'),
      ok(document(meals: false)),
    ]) {
      final repo = MealRepository(MockClient((_) async => response));
      await expectLater(repo.fetch(), throwsFormatException);
    }
  });
}
