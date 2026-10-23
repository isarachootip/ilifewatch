import 'package:flutter_test/flutter_test.dart';
import 'package:ite_watch_care/main.dart';
import 'package:ite_watch_care/screens/bp_category.dart';
import 'package:ite_watch_care/watch/watch_models.dart';

void main() {
  testWidgets('WatchCareApp renders SetupScreen without TextStyle assertion error', (tester) async {
    await tester.pumpWidget(const WatchCareApp());
    expect(find.text('ลงทะเบียนใช้งาน'), findsOneWidget);
  });

  test('BpCategory classifies readings according to Thai hypertension guidelines', () {
    expect(BpCategory.of(120, 78).label, 'ปกติ');
    expect(BpCategory.of(135, 85).label, 'ค่อนข้างสูง');
    expect(BpCategory.of(150, 95).label, 'สูง');
    expect(BpCategory.of(182, 112).label, 'สูงมาก ควรพบแพทย์');
    expect(BpCategory.of(85, 55).label, 'ต่ำ');
  });

  test('BpReading serializes to backend ingest JSON format', () {
    final reading = BpReading(
      measuredAt: DateTime.utc(2026, 10, 23, 12, 0),
      systolic: 128,
      diastolic: 82,
      pulse: 74,
      method: 'cuff',
      status: 'SUCCESS',
      credibility: 1,
      source: 'live',
    );
    final json = reading.toJson();
    expect(json['systolic'], 128);
    expect(json['diastolic'], 82);
    expect(json['method'], 'cuff');
    expect(json['source'], 'live');
  });
}
