import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/controllers/meal_controller.dart';
import 'package:geubsik/repositories/meal_repository.dart';
import 'package:geubsik/screens/debug_meals_screen.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'fixtures.dart';

void main() {
  testWidgets('첫 실행 오류에서 재시도, 메뉴와 날짜 탐색', (tester) async {
    var online = false;
    final repo = MealRepository(
      MockClient((_) async {
        if (!online) return http.Response('', 503);
        return ok(document(meals: {'2026-11-26': day, '2026-11-27': emptyDay}));
      }),
    );
    final c = MealController(
      repo,
      MemoryCache(),
      now: () => DateTime.utc(2026, 11, 25, 15),
    );
    await tester.pumpWidget(MaterialApp(home: DebugMealsScreen(controller: c)));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await c.refresh();
    await tester.pumpAndSettle();
    online = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text(menu), findsOneWidget);
    await tester.tap(find.text('다음 날짜'));
    await tester.pumpAndSettle();
    expect(find.text('메뉴 미등록'), findsNWidgets(3));
    await tester.tap(find.text('다음 날짜'));
    await tester.pumpAndSettle();
    expect(find.textContaining('포함되지'), findsOneWidget);
    await tester.tap(find.text('오늘'));
    await tester.pumpAndSettle();
    expect(find.text(menu), findsOneWidget);
  });
}
