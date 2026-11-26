import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../utils/menu_formatter.dart';
import '../theme/app_theme.dart';

class MealPanel extends StatefulWidget {
  const MealPanel({
    super.key,
    required this.kind,
    required this.items,
    required this.settings,
    this.compact = false,
  });
  final MealKind kind;
  final List<String> items;
  final AppSettings settings;
  final bool compact;

  @override
  State<MealPanel> createState() => _MealPanelState();
}

class _MealPanelState extends State<MealPanel> {
  bool expanded = false;
  @override
  void didUpdateWidget(MealPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.representative != widget.settings.representative ||
        oldWidget.items != widget.items) {
      expanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = widget.kind;
    final accent = theme.brightness == Brightness.dark
        ? Color.lerp(kind.ink, Colors.white, .55)!
        : kind.ink;
    final display = MenuDisplay(
      widget.items,
      hideParentheses: widget.settings.hideParentheses,
    );
    final preview = widget.compact || widget.settings.representative;
    final lines = preview && !expanded ? display.preview : display.full;
    final icon = DecoratedBox(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(widget.compact ? 6 : 10),
        child: Icon(kind.icon, size: widget.compact ? 18 : 23, color: accent),
      ),
    );
    final title = Text(
      kind.label,
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
    final menu = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines.length; i++) ...[
          if (i > 0)
            SizedBox(
              height: lines[i - 1].representative && !lines[i].representative
                  ? 12
                  : 6,
            ),
          Text(
            lines[i].text,
            style: lines[i].special
                ? theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )
                : lines[i].representative
                ? theme.representativeMenuStyle
                : theme.textTheme.bodyLarge?.copyWith(height: 1.6),
          ),
        ],
        if (!lines.any((line) => !line.special && line.text.trim().isNotEmpty))
          Text(
            '등록된 메뉴가 없습니다.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
      ],
    );
    void toggle() => setState(() => expanded = !expanded);

    if (widget.compact) {
      final row = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth <
                  200 * MediaQuery.textScalerOf(context).scale(1);
              final arrow = Icon(
                expanded ? Icons.expand_less : Icons.expand_more,
                color: theme.colorScheme.onSurfaceVariant,
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        icon,
                        const SizedBox(width: 8),
                        Expanded(child: title),
                        if (display.hasMore) arrow,
                      ],
                    ),
                    const SizedBox(height: 6),
                    menu,
                  ],
                );
              }
              return Row(
                children: [
                  icon,
                  const SizedBox(width: 8),
                  title,
                  const SizedBox(width: 12),
                  Expanded(child: menu),
                  if (display.hasMore) ...[const SizedBox(width: 4), arrow],
                ],
              );
            },
          ),
        ),
      );
      if (!display.hasMore) return row;
      return Semantics(
        button: true,
        expanded: expanded,
        child: Tooltip(
          message: '${kind.label} ${expanded ? '접기' : '전체 메뉴 보기'}',
          child: InkWell(
            onTap: toggle,
            borderRadius: BorderRadius.circular(10),
            child: row,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                icon,
                const SizedBox(width: 10),
                Expanded(child: title),
              ],
            ),
            const SizedBox(height: 16),
            menu,
            if (preview && display.hasMore)
              TextButton(
                onPressed: toggle,
                child: Text(expanded ? '접기' : '전체 메뉴 보기'),
              ),
          ],
        ),
      ),
    );
  }
}
