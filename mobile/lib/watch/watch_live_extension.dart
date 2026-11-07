import 'dart:async';

import 'package:flutter/services.dart';

import '../app_state.dart';
import 'watch_service.dart';

/// ส่วนขยายของ WatchService สำหรับสั่งวัด SpO2, อุณหภูมิ, ชีพจรสด,
/// อ่านก้าวเดินปัจจุบัน และสั่งเปิด/ปิดโหมดออกกำลังกายบนนาฬิกา F520Pro จริง
extension WatchLiveExtension on WatchService {
  /// วัดออกซิเจนในเลือดสด (SpO2) จากนาฬิกา F520Pro
  Future<int> measureSpo2() => runQueued(() async {
        final done = events
            .firstWhere((e) => e['type'] == 'spo2Result' || e['type'] == 'spo2Error')
            .timeout(const Duration(seconds: 60));
        await invokeNative('startSpo2');
        final Map<String, dynamic> e;
        try {
          e = await done;
        } finally {
          await invokeNative('stopSpo2');
        }
        if (e['type'] == 'spo2Error') {
          throw PlatformException(code: 'SPO2_${e['status']}', message: bpStatusThai('${e['status']}'));
        }
        return (e['value'] as num).toInt();
      });

  Future<void> cancelSpo2() => invokeNative('stopSpo2');

  /// วัดอุณหภูมิร่างกายสด (°C) จากนาฬิกา F520Pro
  Future<double> measureTemperature() => runQueued(() async {
        final done = events.firstWhere((e) => e['type'] == 'tempResult').timeout(const Duration(seconds: 75));
        await invokeNative('startTemp');
        try {
          final e = await done;
          return (e['celsius'] as num).toDouble();
        } finally {
          await invokeNative('stopTemp');
        }
      });

  Future<void> cancelTemperature() => invokeNative('stopTemp');

  /// วัดชีพจรสด (bpm) จากนาฬิกา F520Pro
  Future<int> measureHeartRate() => runQueued(() async {
        final done = events
            .firstWhere((e) => e['type'] == 'heartResult' || e['type'] == 'heartError')
            .timeout(const Duration(seconds: 45));
        await invokeNative('startHeart');
        final Map<String, dynamic> e;
        try {
          e = await done;
        } finally {
          await invokeNative('stopHeart');
        }
        if (e['type'] == 'heartError') {
          throw PlatformException(code: 'HEART_${e['status']}', message: bpStatusThai('${e['status']}'));
        }
        return (e['bpm'] as num).toInt();
      });

  Future<void> cancelHeartRate() => invokeNative('stopHeart');

  /// อ่านก้าวเดิน, ระยะทาง (กม.), แคลอรี ปัจจุบันจากนาฬิกาทันที (`readSportStep`)
  Future<Map<String, dynamic>> readCurrentSportStep() => runQueued(() async {
        final done = eventsOf('sportStep').first.timeout(const Duration(seconds: 12));
        await invokeNative('readSportStep');
        return done;
      });

  /// สั่งเปิดโหมดออกกำลังกายบนหน้าปัดนาฬิกา (`walk`, `run_out`, `run_in`, `cycle`)
  Future<void> startWatchSportMode(String mode) =>
      runQueued(() => invokeNative('startSportMode', {'mode': mode}));

  /// สั่งหยุดโหมดออกกำลังกายบนหน้าปัดนาฬิกา
  Future<void> stopWatchSportMode() =>
      runQueued(() => invokeNative('stopSportMode'));

  static Completer<Map<String, dynamic>>? _checkupCancel;

  /// สั่งตรวจสุขภาพด่วนในปุ่มเดียว 60 วินาที (One-Tap Mini Checkup: ชีพจร + ความดัน + SpO2 + อุณหภูมิ + ความเครียด + HRV)
  Future<Map<String, dynamic>> runMiniCheckup() => runQueued(() async {
        final s = AppState.instance;
        final cancel = _checkupCancel = Completer<Map<String, dynamic>>();
        final done = Future.any([
          events.firstWhere((e) =>
              e['type'] == 'miniCheckupResult' ||
              e['type'] == 'miniCheckupError' ||
              e['type'] == 'miniCheckupStopped'),
          cancel.future,
        ]).timeout(const Duration(seconds: 95));
        await invokeNative('startMiniCheckup', {
          'heartRate': s.latestHeartRate,
          'spo2': s.latestSpo2,
          'systolic': s.latestBp?.systolic,
          'diastolic': s.latestBp?.diastolic,
          'temperature': s.latestTemperature,
        });
        final Map<String, dynamic> e;
        try {
          e = await done;
        } finally {
          _checkupCancel = null;
          await invokeNative('stopMiniCheckup');
        }
        if (e['type'] == 'miniCheckupStopped') {
          throw PlatformException(code: 'CHECKUP_INTERRUPTED', message: bpStatusThai('INTERRUPTED'));
        }
        if (e['type'] == 'miniCheckupError') {
          throw PlatformException(code: 'CHECKUP_${e['status']}', message: bpStatusThai('${e['status']}'));
        }
        return e;
      });

  Future<void> cancelMiniCheckup() {
    final c = _checkupCancel;
    if (c != null && !c.isCompleted) {
      c.complete({'type': 'miniCheckupStopped'});
    }
    return invokeNative('stopMiniCheckup');
  }

  /// สั่งเปิดโหมดวัดค่าอัตโนมัติ 24 ชม. บนนาฬิกา (Auto HR, Auto BP, Auto Temp, Auto HRV, Auto Stress)
  Future<void> enableWatchAutoDetect() =>
      runQueued(() => invokeNative('enableAutoDetect'));

  /// ตั้งค่าความดันโลหิตอ้างอิงเฉพาะบุคคล (Private BP Calibration) หรือกลับเป็นโหมดมาตรฐาน (Public Mode)
  Future<void> configureBpCalibration({
    required bool privateMode,
    required int systolic,
    required int diastolic,
  }) =>
      runQueued(() => invokeNative('setBpCalibration', {
            'privateMode': privateMode,
            'systolic': systolic,
            'diastolic': diastolic,
          }).timeout(const Duration(seconds: 10)));

  /// เปิด/ปิด Android Foreground Service สำหรับรักษาการเชื่อมต่อและซิงค์ข้อมูล 24 ชม.
  Future<void> setForegroundGuard(bool enabled) async {
    try {
      await invokeNative('setForegroundService', {'enabled': enabled});
    } catch (_) {}
  }
}
