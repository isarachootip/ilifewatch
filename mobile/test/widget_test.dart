import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ite_watch_care/app_state.dart';
import 'package:ite_watch_care/l10n/app_language.dart';
import 'package:ite_watch_care/main.dart';
import 'package:ite_watch_care/screens/bp_category.dart';
import 'package:ite_watch_care/screens/mini_checkup_screen.dart';
import 'package:ite_watch_care/screens/spo2_temp_screen.dart';
import 'package:ite_watch_care/watch/watch_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = AppLanguage.th;
  });

  testWidgets('WatchCareApp renders 5-tab iLife Watch shell and switches tabs', (tester) async {
    await tester.pumpWidget(const WatchCareApp());
    expect(find.text('สุขภาพ'), findsWidgets);
    expect(find.text('ออกกำลังกาย'), findsOneWidget);
    expect(find.text('iLife Care'), findsOneWidget);
    expect(find.text('อุปกรณ์'), findsOneWidget);
    expect(find.text('ฉัน'), findsOneWidget);

    await tester.tap(find.text('iLife Care'));
    await tester.pumpAndSettle();
    expect(find.textContaining('น้ำดื่มอัลคาไลน์'), findsWidgets);

    await tester.tap(find.text('อุปกรณ์'));
    await tester.pumpAndSettle();
    expect(find.textContaining('F520Pro'), findsWidgets);
  });

  testWidgets('WatchCareApp supports switching 5 languages (TH, EN, ZH, AR RTL, DE)', (tester) async {
    await tester.pumpWidget(const WatchCareApp());

    // 1. Default Thai
    expect(find.text('สุขภาพ'), findsWidgets);

    // 2. Switch to English
    await AppState.instance.setLanguage(AppLanguage.en);
    await tester.pumpAndSettle();
    expect(find.text('Health'), findsWidgets);
    expect(find.text('Exercise'), findsOneWidget);
    expect(find.text('Devices'), findsOneWidget);

    // 3. Switch to Chinese (简体中文)
    await AppState.instance.setLanguage(AppLanguage.zh);
    await tester.pumpAndSettle();
    expect(find.text('健康'), findsWidgets);
    expect(find.text('运动'), findsOneWidget);
    expect(find.text('设备'), findsOneWidget);

    // 4. Switch to Arabic (العربية) and verify RTL Directionality
    await AppState.instance.setLanguage(AppLanguage.ar);
    await tester.pumpAndSettle();
    expect(find.text('الصحة'), findsWidgets);
    expect(find.text('التمارين'), findsOneWidget);
    final scaffoldCtx = tester.element(find.byType(Scaffold).first);
    expect(Directionality.of(scaffoldCtx), TextDirection.rtl);

    // 5. Switch to German (Deutsch) and verify LTR restored
    await AppState.instance.setLanguage(AppLanguage.de);
    await tester.pumpAndSettle();
    expect(find.text('Gesundheit'), findsWidgets);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Geräte'), findsOneWidget);
    expect(Directionality.of(tester.element(find.byType(Scaffold).first)), TextDirection.ltr);
  });

  test('BpCategory classifies readings and translates across languages', () {
    AppState.instance.language = AppLanguage.th;
    expect(BpCategory.of(120, 78).label, 'ปกติ');
    expect(BpCategory.of(135, 85).label, 'ค่อนข้างสูง');
    expect(BpCategory.of(150, 95).label, 'สูง');
    expect(BpCategory.of(182, 112).label, 'สูงมาก ควรพบแพทย์');
    expect(BpCategory.of(85, 55).label, 'ต่ำ');

    AppState.instance.language = AppLanguage.en;
    expect(BpCategory.of(120, 78).label, 'Normal');
    expect(BpCategory.of(182, 112).label, 'Hypertensive Crisis (Seek Care)');

    AppState.instance.language = AppLanguage.de;
    expect(BpCategory.of(150, 95).label, 'Hoch');
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

  testWidgets('Spo2TempScreen switches between SpO2, Temperature, and Live Pulse modes', (tester) async {
    AppState.instance.setVital('spo2', 98);
    AppState.instance.setVital('temperature', 36.6);
    AppState.instance.setVital('heart_rate', 72);

    await tester.pumpWidget(const MaterialApp(home: Spo2TempScreen()));
    expect(find.text('98%'), findsOneWidget);

    await tester.tap(find.text('อุณหภูมิ (°C)'));
    await tester.pumpAndSettle();
    expect(find.text('36.6 °C'), findsOneWidget);

    await tester.tap(find.text('ชีพจรสด (bpm)'));
    await tester.pumpAndSettle();
    expect(find.text('72 bpm'), findsOneWidget);
  });

  testWidgets('MiniCheckupScreen displays 6 health metrics and localizes across languages', (tester) async {
    AppState.instance.setVital('heart_rate', 75);
    AppState.instance.setVital('spo2', 99);
    AppState.instance.setVital('temperature', 36.5);

    await tester.pumpWidget(const MaterialApp(home: MiniCheckupScreen()));
    expect(find.text('ตรวจสุขภาพด่วนในปุ่มเดียว (60 วินาที)'), findsWidgets);
    expect(find.text('75 bpm'), findsOneWidget);
    expect(find.text('99%'), findsOneWidget);
    expect(find.text('36.5 °C'), findsOneWidget);

    await AppState.instance.setLanguage(AppLanguage.en);
    await tester.pumpWidget(const MaterialApp(home: MiniCheckupScreen()));
    expect(find.text('One-Tap 60s Health Checkup'), findsWidgets);
  });

  test('VitalSample.isValid enforces medical ranges matching server schema', () {
    final now = DateTime.now();
    expect(VitalSample(now, 'spo2', 98).isValid, isTrue);
    expect(VitalSample(now, 'spo2', -5).isValid, isFalse);
    expect(VitalSample(now, 'spo2', 0).isValid, isFalse);
    expect(VitalSample(now, 'heart_rate', 72).isValid, isTrue);
    expect(VitalSample(now, 'heart_rate', 300).isValid, isFalse);
    expect(VitalSample(now, 'temperature', 36.6).isValid, isTrue);
    expect(VitalSample(now, 'temperature', 25.0).isValid, isFalse);
    expect(VitalSample(now, 'stress', 45).isValid, isTrue);
    expect(VitalSample(now, 'stress', 120).isValid, isFalse);
    expect(VitalSample(now, 'hrv', 55).isValid, isTrue);
    expect(VitalSample(now, 'hrv', -1).isValid, isFalse);
  });

  testWidgets('ProfileTab shows dynamic enrollment code and disconnected sync shows snackbar', (tester) async {
    await AppState.instance.applyLogin({
      'token': 'test-token',
      'patient': {
        'enrollment_code': 'CLIN9999',
        'display_name': 'คุณสมศรี',
        'sex': 'F',
        'height_cm': 158,
        'weight_kg': 54,
        'birth_year': 1955,
      },
      'org': {'name': 'คลินิกทดสอบ', 'type': 'clinic'},
    });

    await tester.pumpWidget(const WatchCareApp());
    await tester.tap(find.text('ฉัน'));
    await tester.pumpAndSettle();

    expect(find.text('CLIN9999'), findsOneWidget);
    expect(find.text('ผูกบัญชี / เปลี่ยนรหัสลงทะเบียน (CARE0001)'), findsNothing);

    await tester.tap(find.text('ซิงค์ล่าสุด'));
    await tester.pumpAndSettle();
    expect(find.text('ไม่ได้เชื่อมต่อนาฬิกา'), findsWidgets);
  });
}
