import 'package:flutter/material.dart';
import '../controllers/settings_controller.dart';
import '../models/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});
  final SettingsController controller;
  @override
  Widget build(BuildContext context) {
    final s = controller.value;
    final theme = Theme.of(context);
    Widget section(String title, List<Widget> items) => Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...items,
            ],
          ),
        ),
      ),
    );
    return ListView(
      key: const PageStorageKey('settings'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        section('화면 테마', [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (mode, label) in [
                (ThemeMode.system, '시스템'),
                (ThemeMode.light, '라이트'),
                (ThemeMode.dark, '다크'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: s.theme == mode,
                  onSelected: (_) => controller.set(s.copyWith(theme: mode)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('배경 색상'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            children: [
              for (final bg in Backdrop.values)
                Semantics(
                  selected: s.background == bg,
                  child: IconButton(
                    tooltip: bg.label,
                    onPressed: () => controller.set(s.copyWith(background: bg)),
                    icon: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(bg.light),
                        border: Border.all(
                          color: s.background == bg
                              ? theme.colorScheme.primary
                              : Colors.grey,
                          width: s.background == bg ? 2 : 1,
                        ),
                      ),
                      child: s.background == bg
                          ? const Icon(
                              Icons.check,
                              size: 18,
                              color: Colors.black87,
                            )
                          : null,
                    ),
                  ),
                ),
            ],
          ),
        ]),
        section('표시할 식사', [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final kind in MealKind.values)
                FilterChip(
                  label: Text(kind.label),
                  selected: s.meals.contains(kind),
                  onSelected: (on) {
                    final meals = {...s.meals};
                    if (on) {
                      meals.add(kind);
                    } else {
                      meals.remove(kind);
                    }
                    if (meals.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('한 끼 이상 선택해 주세요.')),
                      );
                    } else {
                      controller.set(s.copyWith(meals: meals));
                    }
                  },
                ),
            ],
          ),
        ]),
        section('메뉴와 급식표', [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('대표 메뉴만 표시'),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('식단표의 첫 메뉴를 표시합니다. 펼치면 전체 메뉴를 볼 수 있어요.'),
            ),
            value: s.representative,
            onChanged: (v) => controller.set(s.copyWith(representative: v)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('괄호 안 텍스트 숨기기'),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('원산지와 초등 등 괄호 속 정보를 숨깁니다.'),
            ),
            value: s.hideParentheses,
            onChanged: (v) => controller.set(s.copyWith(hideParentheses: v)),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('급식표에서 빈 날짜 숨기기'),
            subtitle: const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('선택한 식사에 메뉴가 있는 날짜만 목록에 표시합니다.'),
            ),
            value: s.hideEmpty,
            onChanged: (v) => controller.set(s.copyWith(hideEmpty: v)),
          ),
        ]),
        if (controller.saveFailed)
          const Text('설정을 저장하지 못했습니다. 현재 화면에는 적용됐습니다.'),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => controller.set(const AppSettings()),
            icon: const Icon(Icons.restore),
            label: const Text('기본 설정으로 초기화'),
          ),
        ),
      ],
    );
  }
}
