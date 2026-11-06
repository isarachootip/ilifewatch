import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ite_watch_care/app_state.dart';
import 'package:ite_watch_care/l10n/app_language.dart';
import 'package:ite_watch_care/screens/mini_checkup_screen.dart';
import 'package:ite_watch_care/screens/pair_screen.dart';
import 'package:ite_watch_care/watch/watch_models.dart';
import 'package:ite_watch_care/watch/watch_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppState.instance.language = AppLanguage.th;
  });

  test('ScannedWatch.isWatchCandidate strictly filters only F520Pro/Veepoo watches', () {
    final f520 = ScannedWatch.fromMap({'name': 'F520Pro', 'mac': 'AA:BB:CC:DD:EE:01', 'rssi': -55, 'isVp': true});
    final vpUnnamed = ScannedWatch.fromMap({'name': 'D800', 'mac': 'B3:99:7A:42:B2:A8', 'rssi': -62, 'isVp': true});
    final bondedF520 = ScannedWatch.fromMap({'name': 'iLife Watch F520Pro', 'mac': 'AA:BB:CC:DD:EE:02', 'rssi': -65, 'isVp': false});
    final carAudio = ScannedWatch.fromMap({'name': 'CAR MULTIMEDIA', 'mac': '74:95:EC:C9:38:3C', 'rssi': -40, 'isVp': false});
    final shokz = ScannedWatch.fromMap({'name': 'OpenDots ONE by Shokz', 'mac': 'A0:0C:E2:21:F2:51', 'rssi': -40, 'isVp': false});
    final idea = ScannedWatch.fromMap({'name': 'Idea', 'mac': 'CA:A2:84:40:23:53', 'rssi': -40, 'isVp': false});
    final bondedD800 = ScannedWatch.fromMap({'name': 'D800', 'mac': 'B3:99:7A:42:B2:A8', 'rssi': -40, 'isVp': false});

    expect(f520.isWatchCandidate(), isTrue);
    expect(vpUnnamed.isWatchCandidate(), isTrue);
    expect(bondedF520.isWatchCandidate(), isTrue);
    expect(carAudio.isWatchCandidate(), isFalse);
    expect(shokz.isWatchCandidate(), isFalse);
    expect(idea.isWatchCandidate(), isFalse);
    expect(bondedD800.isWatchCandidate(), isFalse);
    expect(bondedD800.isWatchCandidate(pairedMac: 'B3:99:7A:42:B2:A8'), isTrue);
  });

  testWidgets('PairScreen renders scanning feedback and troubleshooting guide', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('ite.watch/method'),
      (call) async => null,
    );
    await tester.pumpWidget(const MaterialApp(home: PairScreen()));
    await tester.pump();

    expect(find.textContaining('กำลังสแกนหานาฬิกา F520Pro'), findsOneWidget);
    expect(find.textContaining('5 ขั้นตอนการเชื่อมต่อที่ถูกต้อง'), findsOneWidget);
  });

  test('AppState stores stress and hrv vitals and bpStatusThai translates FUNCTION_NOT_SUPPORT', () {
    AppState.instance.setVital('stress', 36);
    AppState.instance.setVital('hrv', 62);
    expect(AppState.instance.latestStress, 36);
    expect(AppState.instance.latestHrv, 62);
    expect(bpStatusThai('FUNCTION_NOT_SUPPORT'), isNot(contains('FUNCTION_NOT_SUPPORT')));
  });

  testWidgets('MiniCheckupScreen displays latest Stress and HRV from AppState', (tester) async {
    AppState.instance.setVital('stress', 38);
    AppState.instance.setVital('hrv', 64);
    await tester.pumpWidget(const MaterialApp(home: MiniCheckupScreen()));
    await tester.pump();

    expect(find.text('38'), findsOneWidget);
    expect(find.text('64 ms'), findsOneWidget);
  });

  test('WatchService tracks pairing screen lock to prevent background reconnect collision', () {
    WatchService.instance.setPairingActive(true);
    expect(WatchService.instance.isPairingActive, isTrue);
    WatchService.instance.setPairingActive(false);
    expect(WatchService.instance.isPairingActive, isFalse);
  });
}
