import 'dart:convert';

import 'package:flutter/material.dart';

import 'daily_meals.dart';

enum MealKind {
  breakfast('아침', Icons.wb_twilight, Color(0xffa84e19)),
  lunch('점심', Icons.wb_sunny_outlined, Color(0xff946300)),
  dinner('저녁', Icons.nightlight_outlined, Color(0xff66549e));

  const MealKind(this.label, this.icon, this.ink);
  final String label;
  final IconData icon;
  final Color ink;

  List<String> items(DailyMeals day) => switch (this) {
    MealKind.breakfast => day.breakfast,
    MealKind.lunch => day.lunch,
    MealKind.dinner => day.dinner,
  };
}

enum Backdrop {
  gray('기본 회색', 0xfff5f6f8, 0xff191c21),
  cream('크림색', 0xfff5ede1, 0xff221e18),
  blue('연한 파란색', 0xffe7eef8, 0xff171e29),
  green('연한 초록색', 0xffe5f0e7, 0xff18221c),
  violet('연한 보라색', 0xfff0e8f6, 0xff211b26),
  white('흰색', 0xffffffff, 0xff191919);

  const Backdrop(this.label, this.light, this.dark);
  final String label;
  final int light;
  final int dark;
}

enum SchedulePeriod {
  five('오늘부터 5일'),
  seven('오늘부터 7일'),
  week('이번 주'),
  nextWeek('다음 주'),
  month('이번 달'),
  all('등록된 모든 날짜');

  const SchedulePeriod(this.label);
  final String label;
}

class AppSettings {
  const AppSettings({
    this.theme = ThemeMode.system,
    this.background = Backdrop.gray,
    this.meals = const {MealKind.breakfast, MealKind.lunch, MealKind.dinner},
    this.representative = false,
    this.hideParentheses = true,
    this.hideEmpty = false,
    this.period = SchedulePeriod.seven,
  });

  final ThemeMode theme;
  final Backdrop background;
  final Set<MealKind> meals;
  final bool representative, hideParentheses, hideEmpty;
  final SchedulePeriod period;

  AppSettings copyWith({
    ThemeMode? theme,
    Backdrop? background,
    Set<MealKind>? meals,
    bool? representative,
    bool? hideParentheses,
    bool? hideEmpty,
    SchedulePeriod? period,
  }) => AppSettings(
    theme: theme ?? this.theme,
    background: background ?? this.background,
    meals: meals == null || meals.isEmpty
        ? this.meals
        : Set.unmodifiable(meals),
    representative: representative ?? this.representative,
    hideParentheses: hideParentheses ?? this.hideParentheses,
    hideEmpty: hideEmpty ?? this.hideEmpty,
    period: period ?? this.period,
  );

  String encode() => jsonEncode({
    'version': 1,
    'theme': theme.name,
    'background': background.name,
    'meals': meals.map((m) => m.name).toList(),
    'representative': representative,
    'hideParentheses': hideParentheses,
    'hideEmpty': hideEmpty,
    'period': period.name,
  });

  static AppSettings decode(String? raw) {
    const defaults = AppSettings();
    if (raw == null) return defaults;
    try {
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic> || data['version'] != 1) {
        return defaults;
      }
      T? option<T extends Enum>(List<T> options, String field) =>
          options.where((v) => v.name == data[field]).firstOrNull;
      bool? flag(String field) =>
          data[field] is bool ? data[field] as bool : null;
      final enabled = data['meals'];
      return defaults.copyWith(
        theme: option(ThemeMode.values, 'theme'),
        background: option(Backdrop.values, 'background'),
        meals: enabled is List
            ? MealKind.values.where((m) => enabled.contains(m.name)).toSet()
            : null,
        representative: flag('representative'),
        hideParentheses: flag('hideParentheses'),
        hideEmpty: flag('hideEmpty'),
        period: option(SchedulePeriod.values, 'period'),
      );
    } on FormatException {
      return defaults;
    }
  }
}
