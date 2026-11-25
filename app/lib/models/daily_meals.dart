class DailyMeals {
  const DailyMeals._(this.breakfast, this.lunch, this.dinner);

  final List<String> breakfast;
  final List<String> lunch;
  final List<String> dinner;

  factory DailyMeals.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('날짜별 급식 데이터가 올바르지 않습니다.');
    }
    List<String> items(String field) {
      final value = json[field];
      if (value is! List || value.any((item) => item is! String)) {
        throw FormatException('식사 항목을 읽을 수 없습니다.', field);
      }
      return List<String>.unmodifiable(value.cast<String>());
    }

    return DailyMeals._(items('breakfast'), items('lunch'), items('dinner'));
  }
}
