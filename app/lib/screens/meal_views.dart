import 'package:flutter/material.dart';

import '../controllers/meal_controller.dart';
import '../models/app_settings.dart';
import '../utils/korea_date.dart';
import '../utils/meal_dates.dart';
import '../widgets/meal_panel.dart';

class StatusCard extends StatelessWidget {
  const StatusCard(this.title, {super.key, this.detail, this.action});
  final String title;
  final String? detail;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (detail != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(detail!),
            ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: action!),
        ],
      ),
    ),
  );
}

class MealViews extends StatelessWidget {
  const MealViews({
    super.key,
    required this.controller,
    required this.settings,
    required this.schedule,
    required this.onPeriod,
    required this.onOpenDay,
    required this.onAll,
  });
  final MealController controller;
  final AppSettings settings;
  final bool schedule;
  final ValueChanged<SchedulePeriod> onPeriod;
  final ValueChanged<KoreaDate> onOpenDay;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final data = c.snapshot;
    final today = c.today;
    final selected = c.selected;
    final day = data?.forDate(selected);
    final range = bounds(data, today);
    final busy =
        c.status == MealStatus.loading || c.status == MealStatus.refreshing;
    final retry = TextButton(
      onPressed: () => c.refresh(manual: true),
      child: const Text('다시 시도'),
    );
    final dates = schedule && data != null
        ? scheduleDates(data, today, settings)
        : <KoreaDate>[];
    final headingStyle = Theme.of(
      context,
    ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold);
    final header = <Widget>[
      if (busy) const LinearProgressIndicator(),
      if (c.status == MealStatus.stale)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              children: [const Text('최신 정보를 불러오지 못해 이전 급식표를 표시합니다.'), retry],
            ),
          ),
        ),
      if (c.status == MealStatus.ready && c.message != null) Text(c.message!),
      if (schedule)
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<SchedulePeriod>(
            value: settings.period,
            onChanged: (p) {
              if (p != null) onPeriod(p);
            },
            items: [
              for (final p in SchedulePeriod.values)
                DropdownMenuItem(value: p, child: Text(p.label)),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: '이전 날짜',
                      onPressed: selected.compareTo(range.first) > 0
                          ? () => c.select(selected.previous)
                          : null,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Expanded(
                      child: Text(
                        dateLabel(selected, today),
                        style: headingStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      tooltip: '다음 날짜',
                      onPressed: selected.compareTo(range.last) < 0
                          ? () => c.select(selected.next)
                          : null,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
                ),
              ),
              if (selected == today)
                Text(
                  '오늘',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                )
              else
                TextButton(
                  onPressed: () => c.select(today),
                  child: const Text('오늘로 돌아가기'),
                ),
            ],
          ),
        ),
      SizedBox(height: schedule ? 12 : 16),
      if (data == null && c.status == MealStatus.failed)
        StatusCard(
          '급식표를 불러오지 못했습니다.',
          detail: '연결 상태를 확인하고 다시 시도해 주세요.',
          action: retry,
        )
      else if (data == null)
        const Center(child: Text('급식표를 불러오는 중입니다.'))
      else if (data.meals.isEmpty)
        const StatusCard('현재 등록된 급식표가 없습니다.')
      else if (schedule && dates.isEmpty)
        const StatusCard('이 기간에 표시할 날짜가 없습니다.')
      else if (!schedule && day == null)
        StatusCard(
          '등록된 급식표가 없습니다.',
          detail: '이 날짜의 급식표가 아직 등록되지 않았습니다.',
          action: TextButton(onPressed: onAll, child: const Text('등록된 급식표 보기')),
        )
      else if (!schedule && day != null) ...[
        if (MealKind.values.every((kind) => kind.items(day).isEmpty))
          const StatusCard(
            '등록된 메뉴가 없습니다.',
            detail: '급식표에 날짜는 있지만 메뉴가 아직 입력되지 않았습니다.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final panels = [
                for (final kind in MealKind.values)
                  if (settings.meals.contains(kind))
                    MealPanel(
                      key: ValueKey('${selected.key}-${kind.name}'),
                      kind: kind,
                      items: kind.items(day),
                      settings: settings,
                    ),
              ];
              final wide =
                  constraints.maxWidth >=
                  820 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 2);
              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final panel in panels) ...[
                      if (panel != panels.first) const SizedBox(width: 16),
                      Expanded(child: panel),
                    ],
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final panel in panels) ...[
                    if (panel != panels.first) const SizedBox(height: 16),
                    panel,
                  ],
                ],
              );
            },
          ),
      ],
    ];
    final listDates = data != null && data.meals.isNotEmpty
        ? dates
        : <KoreaDate>[];
    return RefreshIndicator(
      onRefresh: () => c.refresh(manual: true),
      child: ListView.builder(
        key: PageStorageKey(
          schedule
              ? 'schedule-${settings.period.name}'
              : 'today-${selected.key}',
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: 1 + listDates.length + (data != null ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: header,
            );
          }
          if (i > listDates.length) {
            return Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Text(
                '마지막 데이터 업데이트  ${updateLabel(data!.updatedAt)}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          }
          final date = listDates[i - 1];
          final meals = data!.forDate(date);
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextButton(
                      onPressed: () => onOpenDay(date),
                      style: TextButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${dateLabel(date, today)}${date == today ? ' · 오늘' : ''}',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                    if (meals == null)
                      const Text('등록된 급식표가 없습니다.')
                    else if (MealKind.values.every(
                      (kind) => kind.items(meals).isEmpty,
                    ))
                      const Text('등록된 메뉴가 없습니다.')
                    else
                      for (final kind in MealKind.values)
                        if (settings.meals.contains(kind)) ...[
                          const Divider(height: 8),
                          MealPanel(
                            key: ValueKey('${date.key}-${kind.name}'),
                            kind: kind,
                            items: kind.items(meals),
                            settings: settings,
                            compact: true,
                          ),
                        ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
