import 'package:flutter/material.dart';

import '../controllers/meal_controller.dart';

class DebugMealsScreen extends StatelessWidget {
  const DebugMealsScreen({super.key, required this.controller});
  final MealController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('급식')),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final c = controller;
            final day = c.snapshot?.forDate(c.selected);
            final busy =
                c.status == MealStatus.loading ||
                c.status == MealStatus.refreshing;
            final failed =
                c.status == MealStatus.failed || c.status == MealStatus.stale;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('오늘 (한국)  ${c.today.key}'),
                Text('선택한 날짜  ${c.selected.key}'),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => c.select(c.selected.previous),
                      child: const Text('이전 날짜'),
                    ),
                    TextButton(
                      onPressed: () => c.select(c.today),
                      child: const Text('오늘'),
                    ),
                    TextButton(
                      onPressed: () => c.select(c.selected.next),
                      child: const Text('다음 날짜'),
                    ),
                    TextButton(
                      onPressed: busy ? null : () => c.refresh(manual: true),
                      child: Text(failed ? '다시 시도' : '새로고침'),
                    ),
                  ],
                ),
                if (busy) const LinearProgressIndicator(),
                Text(switch (c.status) {
                  MealStatus.loading => '급식표를 불러오는 중입니다.',
                  MealStatus.refreshing => '최신 급식표를 확인하는 중입니다.',
                  MealStatus.ready => '원격 급식표를 확인했습니다.',
                  MealStatus.stale => '최신 급식표 확인에 실패했습니다. 이전 데이터를 표시합니다.',
                  MealStatus.failed => '급식표를 불러오지 못했습니다.',
                }),
                if (c.message != null) Text(c.message!),
                if (c.snapshot != null) ...[
                  Text(
                    '데이터 출처  ${c.source == MealSource.cache ? '기기 캐시' : '원격 응답'}',
                  ),
                  Text('데이터 변경 시각  ${c.snapshot!.updatedAt}'),
                  const Divider(),
                  if (day == null)
                    const Text('이 날짜는 현재 급식표에 포함되지 않았습니다.')
                  else
                    for (final (label, items) in [
                      ('조식', day.breakfast),
                      ('중식', day.lunch),
                      ('석식', day.dinner),
                    ]) ...[
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(items.isEmpty ? '메뉴 미등록' : items.join('\n')),
                      const SizedBox(height: 12),
                    ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
