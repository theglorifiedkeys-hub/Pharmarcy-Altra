import 'package:csv/csv.dart';
import 'package:timezone/timezone.dart' as tz;

const sections = ['Dawa', 'Clients', 'Suppliers', 'Reminders'];
const fields = [
  ['Name', 'Form', 'Supplier', 'Stock', 'Expiry'],
  ['Name', 'Phone', 'Visit notes'],
  ['Name', 'Location', 'Phone'],
  ['Title', 'Due', 'Category'],
];
String dayString(DateTime date) => date.toIso8601String().substring(0, 10);
String todayInTanzania() => dayString(tz.TZDateTime.now(tz.getLocation('Africa/Dar_es_Salaam')));

class PharmacyRecord {
  PharmacyRecord(this.id, this.values, [this.photo]);
  factory PharmacyRecord.fromJson(Map<String, dynamic> json) => PharmacyRecord(
    json['id'] as int,
    List<String>.from(json['values'] as List),
    json['photo'] as String?,
  );
  final int id;
  final List<String> values;
  final String? photo;
  Map<String, dynamic> toJson() => {'id': id, 'values': values, 'photo': photo};
}

bool validDate(String text) {
  final value = DateTime.tryParse(text);
  return RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text) &&
      value != null && dayString(value) == text;
}

String? validateRecord(int section, List<String> values) {
  if (values.length != fields[section].length ||
      values.any((text) => text.trim().isEmpty || text.length > 500)) {
    return 'Fill all fields (up to 500 characters each).';
  }
  if (section == 0 && (int.tryParse(values[3]) ?? -1) < 0) {
    return 'Stock must be a non-negative whole number.';
  }
  if ((section == 0 && !validDate(values[4])) ||
      (section == 3 && !validDate(values[1]))) {
    return 'Use a valid date in YYYY-MM-DD format.';
  }
  return null;
}

List<List<String>> parseMedicines(String source) {
  final text = source.startsWith('\ufeff') ? source.substring(1) : source;
  final rows = const CsvToListConverter(
    shouldParseNumbers: false, allowInvalid: false, eol: '\n',
  ).convert(text.replaceAll('\r\n', '\n')).map(
    (row) => row.map((value) => value.toString().trim()).toList(),
  ).where((row) => row.any((value) => value.isNotEmpty)).toList();
  if (rows.length < 2 || rows.first.join(',') != 'name,form,supplier,stock,expiry') {
    throw const FormatException('Use the CSV header name,form,supplier,stock,expiry with at least one medicine.');
  }
  if (rows.length > 501) throw const FormatException('Import at most 500 medicines at a time.');
  for (var i = 1; i < rows.length; i++) {
    final error = validateRecord(0, rows[i]);
    if (error != null) throw FormatException('Medicine $i: $error');
  }
  return rows.skip(1).toList();
}
