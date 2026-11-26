import '../models/app_settings.dart';
import '../models/daily_meals.dart';

typedef MenuLine = ({String text, bool special, bool representative});

bool _special(String line) => RegExp(r'^<[^<>]+>$').hasMatch(line.trim());

/// Remove only matched spans within a line. An unmatched "(" keeps its text.
String withoutParentheses(String line) {
  final opens = <int>[];
  final ends = <int, int>{};
  for (var i = 0; i < line.length; i++) {
    if (line[i] == '(') opens.add(i);
    if (line[i] == ')' && opens.isNotEmpty) ends[opens.removeLast()] = i;
  }
  if (ends.isEmpty) return line;
  final result = StringBuffer();
  for (var i = 0; i < line.length; i++) {
    final end = ends[i];
    if (end != null) {
      // Drop commas separating two removed annotations, e.g. (원산지),(부위).
      final separator = RegExp(
        r'^\s*[,，]\s*(?=\()',
      ).firstMatch(line.substring(end + 1));
      i = end;
      if (separator != null && ends.containsKey(end + 1 + separator.end)) {
        i += separator.end;
      }
    } else {
      result.write(line[i]);
    }
  }
  var cleaned = result.toString();
  if (line.trimRight().endsWith(')')) {
    cleaned = cleaned.replaceFirst(RegExp(r'[,，]\s*$'), '');
  }
  return cleaned.replaceAll(RegExp(r' {2,}'), ' ').trim();
}

class MenuDisplay {
  MenuDisplay(List<String> raw, {required bool hideParentheses}) {
    for (final item in raw) {
      final lines = <MenuLine>[];
      for (final line in item.split('\n')) {
        final special = _special(line);
        final menuName = special ? '' : withoutParentheses(line);
        final text = hideParentheses && !special ? menuName : line;
        if (hideParentheses && text.isEmpty && line.isNotEmpty) continue;
        lines.add((
          text: text,
          special: special,
          representative: !_foundFirst && menuName.trim().isNotEmpty,
        ));
      }
      full.addAll(lines);
      if (!_foundFirst) {
        preview.addAll(lines);
        _foundFirst = lines.any((line) => line.representative);
      }
    }
  }
  final full = <MenuLine>[];
  final preview = <MenuLine>[];
  bool _foundFirst = false;
  bool get hasMore => full.length > preview.length;
}

bool hasMenu(DailyMeals? day, Iterable<MealKind> kinds) =>
    day != null &&
    kinds.any(
      (kind) => kind
          .items(day)
          .any(
            (item) => item
                .split('\n')
                .any((line) => line.trim().isNotEmpty && !_special(line)),
          ),
    );
