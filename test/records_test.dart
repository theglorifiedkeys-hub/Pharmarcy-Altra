import 'package:altra_pharmacy/features/records.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const header = 'name,form,supplier,stock,expiry';
  test('imports quoted medicine names and CRLF with a BOM', () {
    final rows = parseMedicines('\ufeff$header\r\n"Zinc, demo",Tablet,Afya,24,2028-09-30\r\n');
    expect(rows.single, ['Zinc, demo', 'Tablet', 'Afya', '24', '2028-09-30']);
  });
  test('rejects malformed dates and negative stock', () {
    expect(() => parseMedicines('$header\nDemo,Tablet,Afya,-1,2028-09-30'), throwsFormatException);
    expect(() => parseMedicines('$header\nDemo,Tablet,Afya,24,2028-02-31'), throwsFormatException);
  });
  test('keeps record identifier, fields and photo through serialization', () {
    final record = PharmacyRecord(7, ['Demo', 'Tablet', 'Afya', '24', '2028-09-30'], 'image');
    final restored = PharmacyRecord.fromJson(record.toJson());
    expect(restored.id, 7);
    expect(restored.values, record.values);
    expect(restored.photo, 'image');
  });
}
