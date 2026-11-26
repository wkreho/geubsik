/// A calendar day. UTC midnight is used only for calendar arithmetic.
class KoreaDate implements Comparable<KoreaDate> {
  const KoreaDate._(this._day);

  final DateTime _day;
  DateTime get calendar => _day;
  factory KoreaDate.ymd(int year, int month, int day) =>
      KoreaDate._(DateTime.utc(year, month, day));
  KoreaDate shift(int days) => KoreaDate._(_day.add(Duration(days: days)));

  factory KoreaDate.today([DateTime? instant]) {
    final korea = (instant ?? DateTime.now()).toUtc().add(
      const Duration(hours: 9),
    );
    return KoreaDate._(DateTime.utc(korea.year, korea.month, korea.day));
  }

  factory KoreaDate.parse(String key) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
      throw const FormatException('날짜 형식이 올바르지 않습니다.');
    }
    final parts = key.split('-').map(int.parse).toList();
    final result = KoreaDate._(DateTime.utc(parts[0], parts[1], parts[2]));
    if (parts[0] == 0 || result.key != key) {
      throw FormatException('존재하지 않는 날짜입니다.', key);
    }
    return result;
  }

  String get key =>
      '${_day.year.toString().padLeft(4, '0')}-'
      '${_day.month.toString().padLeft(2, '0')}-'
      '${_day.day.toString().padLeft(2, '0')}';

  KoreaDate get previous => KoreaDate._(_day.subtract(const Duration(days: 1)));
  KoreaDate get next => KoreaDate._(_day.add(const Duration(days: 1)));
  bool isToday([DateTime? instant]) => this == KoreaDate.today(instant);

  Iterable<KoreaDate> through(KoreaDate end) sync* {
    for (var day = this; day.compareTo(end) <= 0; day = day.next) {
      yield day;
    }
  }

  @override
  int compareTo(KoreaDate other) => _day.compareTo(other._day);

  @override
  bool operator ==(Object other) => other is KoreaDate && _day == other._day;

  @override
  int get hashCode => _day.hashCode;
}
