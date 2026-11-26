import 'package:flutter/material.dart';

import '../controllers/meal_controller.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings.dart';
import '../utils/korea_date.dart';
import '../widgets/meal_calendar.dart';
import 'meal_views.dart';
import 'settings_screen.dart';

class MealShell extends StatefulWidget {
  const MealShell({super.key, required this.meals, required this.settings});
  final MealController meals;
  final SettingsController settings;
  @override
  State<MealShell> createState() => _MealShellState();
}

class _MealShellState extends State<MealShell> {
  int tab = 0;
  void openDay(KoreaDate d) {
    widget.meals.select(d);
    setState(() => tab = 0);
  }

  Future<void> calendar() async {
    final result = await showDialog<KoreaDate>(
      context: context,
      builder: (_) => MealCalendar(meals: widget.meals),
    );
    if (mounted && result != null) openDay(result);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.meals, widget.settings]),
    builder: (context, _) {
      final c = widget.meals;
      final prefs = widget.settings;
      final busy =
          c.status == MealStatus.loading || c.status == MealStatus.refreshing;
      final width = switch (tab) {
        0 => 1100.0,
        1 => 760.0,
        _ => 680.0,
      };
      return Scaffold(
        body: SafeArea(
          bottom: false,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: width),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Semantics(
                            header: true,
                            child: Text(
                              ['급식', '급식표', '설정'][tab],
                              style:
                                  Theme.of(
                                    context,
                                  ).appBarTheme.titleTextStyle ??
                                  Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                        ),
                        if (tab != 2)
                          IconButton(
                            tooltip: '새로고침',
                            onPressed: busy
                                ? null
                                : () => c.refresh(manual: true),
                            icon: const Icon(Icons.refresh),
                          ),
                        if (tab == 0)
                          IconButton(
                            tooltip: '달력 열기',
                            onPressed: calendar,
                            icon: const Icon(Icons.calendar_month_outlined),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: tab == 2
                        ? SettingsScreen(controller: prefs)
                        : MealViews(
                            controller: c,
                            settings: prefs.value,
                            schedule: tab == 1,
                            onOpenDay: openDay,
                            onPeriod: (p) =>
                                prefs.set(prefs.value.copyWith(period: p)),
                            onAll: () {
                              prefs.set(
                                prefs.value.copyWith(
                                  period: SchedulePeriod.all,
                                ),
                              );
                              setState(() => tab = 1);
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (i) {
            if (i == 0 && tab == 0) c.select(c.today);
            setState(() => tab = i);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined),
              selectedIcon: Icon(Icons.restaurant),
              label: '오늘',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_view_week_outlined),
              selectedIcon: Icon(Icons.calendar_view_week),
              label: '급식표',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      );
    },
  );
}
