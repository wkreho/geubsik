import 'package:flutter/material.dart';
import '../controllers/meal_controller.dart';
import '../utils/korea_date.dart';
import '../utils/meal_dates.dart';

class MealCalendar extends StatefulWidget {
  const MealCalendar({super.key, required this.meals});
  final MealController meals;
  @override
  State<MealCalendar> createState() => _MealCalendarState();
}

class _MealCalendarState extends State<MealCalendar> {
  late DateTime month;
  @override
  void initState() {
    super.initState();
    final d = widget.meals.selected.calendar;
    month = DateTime.utc(d.year, d.month);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.meals,
    builder: (context, _) {
      final c = widget.meals;
      final range = bounds(c.snapshot, c.today);
      DateTime startOf(KoreaDate d) =>
          DateTime.utc(d.calendar.year, d.calendar.month);
      final first = startOf(range.first);
      final last = startOf(range.last);
      final shown = month.isBefore(first)
          ? first
          : month.isAfter(last)
          ? last
          : month;
      void move(int delta) =>
          setState(() => month = DateTime.utc(shown.year, shown.month + delta));
      final firstOffset = shown.weekday % 7;
      final count = DateTime.utc(shown.year, shown.month + 1, 0).day;
      final colors = Theme.of(context).colorScheme;
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 410),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '이전 달',
                      onPressed: shown.isAfter(first) ? () => move(-1) : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        '${shown.year}년 ${shown.month}월',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 달',
                      onPressed: shown.isBefore(last) ? () => move(1) : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
                Table(
                  children: [
                    TableRow(
                      children: [
                        for (final w in ['일', '월', '화', '수', '목', '금', '토'])
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Center(child: Text(w)),
                          ),
                      ],
                    ),
                    for (
                      var row = 0;
                      row < (firstOffset + count + 6) ~/ 7;
                      row++
                    )
                      TableRow(
                        children: [
                          for (var col = 0; col < 7; col++)
                            Builder(
                              builder: (context) {
                                final n = row * 7 + col - firstOffset + 1;
                                if (n < 1 || n > count) {
                                  return const SizedBox.shrink();
                                }
                                final day = KoreaDate.ymd(
                                  shown.year,
                                  shown.month,
                                  n,
                                );
                                final enabled = selectable(
                                  day,
                                  c.today,
                                  c.snapshot,
                                );
                                final selected = day == c.selected;
                                return Semantics(
                                  label: dateLabel(day, c.today),
                                  selected: selected,
                                  child: TextButton(
                                    key: ValueKey(day.key),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      backgroundColor: selected && enabled
                                          ? colors.primaryContainer
                                          : null,
                                      side: day == c.today
                                          ? BorderSide(color: colors.primary)
                                          : null,
                                    ),
                                    onPressed: enabled
                                        ? () => Navigator.pop(context, day)
                                        : null,
                                    child: Text('$n'),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('닫기'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, c.today),
                      child: const Text('오늘로 이동'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
