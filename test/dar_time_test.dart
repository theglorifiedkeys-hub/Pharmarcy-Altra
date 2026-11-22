import 'package:altra_pharmacy/core/dar_time.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('greets by the Dar es Salaam hour', () {
    expect(darGreeting(7), 'Habari za asubuhi');
    expect(darGreeting(14), 'Habari za mchana');
    expect(darGreeting(21), 'Habari za jioni');
  });

  test('formats a Swahili weekday label for the header', () {
    expect(darDateLabel(DateTime(2026, 11, 20)), 'Ijumaa, 20 Nov 2026');
  });

  test('counts whole days until an expiry date', () {
    final today = darNow();
    final later = DateTime(
      today.year,
      today.month,
      today.day,
    ).add(const Duration(days: 3));
    expect(daysUntil(later.toIso8601String().substring(0, 10)), 3);
  });
}
