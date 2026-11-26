import '../models/app_settings.dart';
import '../models/meal_snapshot.dart';
import 'korea_date.dart';
import 'menu_formatter.dart';

const weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String dateLabel(KoreaDate day, KoreaDate today) {
  final d = day.calendar;
  final year = d.year == today.calendar.year ? '' : '${d.year}년 ';
  return '$year${d.month}월 ${d.day}일 ${weekdays[d.weekday - 1]}요일';
}

String updateLabel(String stamp) {
  final d = DateTime.parse(stamp).toUtc().add(const Duration(hours: 9));
  final hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '${d.month}월 ${d.day}일 ${d.hour < 12 ? '오전' : '오후'} $hour:${d.minute.toString().padLeft(2, '0')}';
}

({KoreaDate first, KoreaDate last}) bounds(
  MealSnapshot? data,
  KoreaDate today,
) {
  final first = data?.firstDate;
  final last = data?.lastDate;
  return (
    first: first != null && first.compareTo(today.key) < 0
        ? KoreaDate.parse(first)
        : today,
    last: last != null && last.compareTo(today.key) > 0
        ? KoreaDate.parse(last)
        : today,
  );
}

bool selectable(KoreaDate day, KoreaDate today, MealSnapshot? data) =>
    day == today || hasMenu(data?.forDate(day), MealKind.values);

List<KoreaDate> scheduleDates(
  MealSnapshot data,
  KoreaDate today,
  AppSettings settings,
) {
  final d = today.calendar;
  final monday = today.shift(1 - d.weekday);
  final days = switch (settings.period) {
    SchedulePeriod.five => today.through(today.shift(4)),
    SchedulePeriod.seven => today.through(today.shift(6)),
    SchedulePeriod.week => monday.through(monday.shift(6)),
    SchedulePeriod.nextWeek => monday.shift(7).through(monday.shift(13)),
    SchedulePeriod.month => KoreaDate.ymd(
      d.year,
      d.month,
      1,
    ).through(KoreaDate.ymd(d.year, d.month + 1, 0)),
    SchedulePeriod.all => data.dates.map(KoreaDate.parse),
  };
  return days
      .where(
        (day) =>
            !settings.hideEmpty || hasMenu(data.forDate(day), settings.meals),
      )
      .toList();
}
