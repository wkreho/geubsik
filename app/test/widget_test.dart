import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geubsik/controllers/meal_controller.dart';
import 'package:geubsik/controllers/settings_controller.dart';
import 'package:geubsik/repositories/meal_repository.dart';
import 'package:geubsik/screens/meal_shell.dart';
import 'package:geubsik/screens/settings_screen.dart';
import 'package:geubsik/models/app_settings.dart';
import 'package:geubsik/theme/app_theme.dart';
import 'package:geubsik/widgets/meal_panel.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fixtures.dart';

class _Storage implements SettingsStorage {
  String? data;
  @override
  Future<String?> read() async => data;
  @override
  Future<void> write(String value) async {
    data = value;
  }
}

MealController controller(MockClient client, [MemoryCache? cache]) =>
    MealController(
      MealRepository(client),
      cache ?? MemoryCache(),
      now: () => DateTime.utc(2026, 11, 25, 15),
    );

Future<void> show(
  WidgetTester tester,
  MealController c,
  SettingsController prefs,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: MealShell(meals: c, settings: prefs),
    ),
  );
}

void main() {
  testWidgets('설정의 APK 링크는 웹 전용이며 외부 링크 실패 후에도 설정이 유지된다', (tester) async {
    final opened = <Uri>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsScreen(
            controller: SettingsController(_Storage()),
            openLink: (url) async {
              opened.add(url);
              return false;
            },
          ),
        ),
      ),
    );
    Future<void> tapLink(Finder link) async {
      final target = link.hitTestable();
      await tester.scrollUntilVisible(target, 180);
      await tester.pumpAndSettle();
      expect(target, findsOneWidget);
      final previousCalls = opened.length;
      await tester.tap(target);
      await tester.pumpAndSettle();
      expect(opened, hasLength(previousCalls + 1));
    }

    await tester.scrollUntilVisible(find.text('앱 정보').hitTestable(), 180);
    await tester.pumpAndSettle();
    final download = find.text('Android 앱 다운로드');
    expect(download, kIsWeb ? findsOneWidget : findsNothing);
    if (kIsWeb) {
      await tapLink(download);
      expect(
        opened.single.toString(),
        'https://github.com/wkreho/geubsik/releases/latest/download/geubsik.apk',
      );
      expect(find.byType(SnackBar), findsOneWidget);
      ScaffoldMessenger.of(tester.element(download)).removeCurrentSnackBar();
      await tester.pumpAndSettle();
    }
    await tapLink(find.text('소스 코드 및 업데이트 내역'));
    expect(
      opened.last.toString(),
      'https://github.com/wkreho/geubsik/releases',
    );
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('앱 정보'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('첫 연결 실패와 재시도, 등록된 빈 날·누락일·오늘 복귀', (tester) async {
    var online = false;
    final c = controller(
      MockClient(
        (_) async => online
            ? ok(
                document(
                  meals: {
                    '2026-11-26': day,
                    '2026-11-27': emptyDay,
                    '2026-11-29': day,
                  },
                ),
              )
            : http.Response('', 503),
      ),
    );
    await show(tester, c, SettingsController(_Storage()));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.text('등록된 급식표가 없습니다.'), findsNothing);
    await c.refresh();
    await tester.pumpAndSettle();
    online = true;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('닭구이'), findsOneWidget);
    await tester.tap(find.byTooltip('다음 날짜'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 메뉴가 없습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('다음 날짜'));
    await tester.pumpAndSettle();
    expect(find.text('등록된 급식표가 없습니다.'), findsOneWidget);
    await tester.tap(find.byTooltip('이전 날짜'));
    await tester.pumpAndSettle();
    expect(c.selected.key, '2026-11-27');
    await tester.tap(find.text('오늘로 돌아가기'));
    await tester.pumpAndSettle();
    expect(c.selected, c.today);
  });

  testWidgets('캐시 배너, 설정 탭 필터, 대표 메뉴 펼치기, 급식표 날짜 상세', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cache = MemoryCache(
      document(
        meals: {
          '2026-11-26': {
            ...day,
            'lunch': [menu, '후식'],
          },
          '2026-11-27': day,
        },
      ),
    );
    var requests = 0;
    final c = controller(
      MockClient((_) async {
        requests++;
        return http.Response('', 503);
      }),
      cache,
    );
    final prefs = SettingsController(_Storage());
    await c.refresh();
    await show(tester, c, prefs);
    expect(find.textContaining('이전 급식표'), findsOneWidget);
    await tester.tap(find.text('설정').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '아침'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, '대표 메뉴만 표시');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(NavigationDestination).first);
    await tester.pumpAndSettle();
    expect(find.text('아침'), findsNothing);
    expect(find.text('후식'), findsNothing);
    final expand = find.text('전체 메뉴 보기').first;
    await tester.ensureVisible(expand);
    await tester.tap(expand);
    await tester.pumpAndSettle();
    expect(find.text('후식'), findsOneWidget);
    await tester.tap(find.byType(NavigationDestination).at(1));
    await tester.pumpAndSettle();
    final lunch = find.byTooltip('점심 전체 메뉴 보기');
    await tester.ensureVisible(lunch);
    await tester.tap(lunch);
    await tester.pumpAndSettle();
    expect(find.text('후식'), findsOneWidget);
    await tester.tap(find.byTooltip('점심 접기'));
    await tester.pumpAndSettle();
    expect(find.text('후식'), findsNothing);
    final next = find.text('11월 27일 금요일');
    await tester.scrollUntilVisible(
      next,
      350,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(c.selected.key, '2026-11-27');
    expect(requests, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('좁은 급식표의 특식과 여러 줄 대표 메뉴는 테마 및 펼침 상태에 맞게 표시된다', (tester) async {
    const settings = AppSettings();
    for (final brightness in Brightness.values) {
      final theme = mealTheme(Backdrop.gray, brightness);
      final lead = brightness == Brightness.light
          ? const Color(0xffb94a4a)
          : const Color(0xfff2a5a5);
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
              child: const SizedBox(
                width: 280,
                child: MealPanel(
                  kind: MealKind.lunch,
                  items: ['<특식>\n반마리닭구이(닭:국산)\n닭다리살구이', '밥'],
                  settings: settings,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      TextStyle? style(String text) =>
          tester.widget<Text>(find.text(text)).style;
      expect(style('<특식>')?.color, theme.colorScheme.primary);
      expect(style('반마리닭구이')?.color, lead);
      expect(style('닭다리살구이')?.fontWeight, FontWeight.w500);
      expect(find.text('밥'), findsNothing);
      await tester.tap(find.byTooltip('점심 전체 메뉴 보기'));
      await tester.pumpAndSettle();
      expect(style('밥')?.color, isNot(lead));
      expect(style('닭다리살구이')?.color, lead);
      await tester.tap(find.byTooltip('점심 접기'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('달력 비활성 날짜와 오늘 예외, 빈 스냅샷과 반응형', (tester) async {
    var empty = false;
    final c = controller(
      MockClient(
        (_) async => ok(
          document(
            meals: empty ? {} : {'2026-11-27': emptyDay, '2026-11-29': day},
          ),
        ),
      ),
    );
    final prefs = SettingsController(_Storage());
    await c.refresh();
    for (final size in [const Size(360, 740), const Size(1200, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await show(tester, c, prefs);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('달력 열기'));
      await tester.pumpAndSettle();
      TextButton button(String key) =>
          tester.widget<TextButton>(find.byKey(ValueKey(key)));
      expect(button('2026-11-27').onPressed, isNull);
      expect(button('2026-11-28').onPressed, isNull);
      expect(button('2026-11-26').onPressed, isNotNull);
      await tester.tap(find.byKey(const ValueKey('2026-11-29')));
      await tester.pumpAndSettle();
      expect(c.selected.key, '2026-11-29');
      expect(tester.takeException(), isNull);
    }
    empty = true;
    await c.refresh();
    await tester.pumpAndSettle();
    expect(find.text('현재 등록된 급식표가 없습니다.'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });
}
