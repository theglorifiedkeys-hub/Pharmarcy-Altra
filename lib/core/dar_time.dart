import 'package:timezone/timezone.dart' as tz;

/// Clock and greeting helpers shared by the workspace header.
DateTime darNow() => tz.TZDateTime.now(tz.getLocation('Africa/Dar_es_Salaam'));

String darGreeting(int hour) => switch (hour) {
  >= 5 && < 12 => 'Habari za asubuhi',
  >= 12 && < 17 => 'Habari za mchana',
  _ => 'Habari za jioni',
};

const _weekdays = [
  'Jumatatu',
  'Jumanne',
  'Jumatano',
  'Alhamisi',
  'Ijumaa',
  'Jumamosi',
  'Jumapili',
];
const _months = [
  'Jan',
  'Feb',
  'Mac',
  'Apr',
  'Mei',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Okt',
  'Nov',
  'Des',
];

/// e.g. "Alhamisi, 20 Nov 2026" without pulling in `intl`.
String darDateLabel(DateTime time) =>
    '${_weekdays[time.weekday - 1]}, ${time.day} ${_months[time.month - 1]} ${time.year}';

/// Whole days from today (Dar es Salaam) until an ISO `YYYY-MM-DD` date.
int daysUntil(String isoDate) {
  final today = darNow();
  final start = DateTime(today.year, today.month, today.day);
  final target = DateTime.tryParse(isoDate);
  if (target == null) return 0;
  return DateTime(target.year, target.month, target.day).difference(start).inDays;
}
