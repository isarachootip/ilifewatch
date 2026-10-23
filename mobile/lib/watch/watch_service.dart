import 'dart:async';

import 'package:flutter/services.dart';

import 'watch_models.dart';

/// ตัวเชื่อมระหว่าง Flutter กับ Veepoo SDK ฝั่ง native
///
/// - Android: android/app/src/main/kotlin/com/ite/ite_watch_care/VeepooBridge.kt
/// - iOS:     ios/Runner/VeepooBridge.swift
///
/// ทั้งสองฝั่งส่ง event รูปแบบเดียวกัน (Map ที่มี key "type") ผ่าน EventChannel เดียว
/// หมายเหตุ: นาฬิกาทำงานได้ทีละคำสั่ง (SDK ระบุว่าห้ามสั่งพร้อมกัน)
/// คลาสนี้จึงมีคิว [_run] ให้คำสั่งที่ใช้เวลานานทำทีละอย่าง
class WatchService {
  WatchService._();
  static final WatchService instance = WatchService._();

  static const _method = MethodChannel('ite.watch/method');
  static const _events = EventChannel('ite.watch/events');

  Stream<Map<String, dynamic>>? _stream;

  /// stream ของ event ดิบทั้งหมดจากนาฬิกา
  Stream<Map<String, dynamic>> get events => _stream ??= _events
      .receiveBroadcastStream()
      .map((e) => Map<String, dynamic>.from(e as Map))
      .asBroadcastStream();

  Stream<Map<String, dynamic>> eventsOf(String type) =>
      events.where((e) => e['type'] == type);

  Stream<ScannedWatch> get scanResults =>
      eventsOf('scan').map(ScannedWatch.fromMap);

  Stream<WatchConnection> get connection =>
      eventsOf('connection').map((e) => connectionFromString(e['state'] as String));

  WatchConnection _state = WatchConnection.disconnected;
  WatchConnection get state => _state;
  Map<String, dynamic>? deviceInfo;

  bool _listening = false;
  void ensureListening() {
    if (_listening) return;
    _listening = true;
    connection.listen((s) => _state = s);
    eventsOf('deviceInfo').listen((e) => deviceInfo = e);
  }

  // ---------- คิวคำสั่ง ----------
  Future<void> _queue = Future.value();
  Future<T> _run<T>(Future<T> Function() task) {
    final c = Completer<T>();
    _queue = _queue.then((_) async {
      try {
        c.complete(await task());
      } catch (e, st) {
        c.completeError(e, st);
      }
    });
    return c.future;
  }

  // ---------- เชื่อมต่อ ----------
  Future<void> startScan() {
    ensureListening();
    return _method.invokeMethod('startScan');
  }

  Future<void> stopScan() => _method.invokeMethod('stopScan');

  /// เชื่อมต่อ แล้วรอจนยืนยันรหัสผ่านสำเร็จ (state = ready)
  Future<void> connect(String mac, {String password = '0000'}) async {
    ensureListening();
    final ready = connection
        .firstWhere((s) => s == WatchConnection.ready || s == WatchConnection.failed)
        .timeout(const Duration(seconds: 40));
    await _method.invokeMethod('connect', {'mac': mac, 'password': password});
    final s = await ready;
    if (s != WatchConnection.ready) {
      throw PlatformException(code: 'CONNECT_FAILED', message: 'เชื่อมต่อนาฬิกาไม่สำเร็จ');
    }
  }

  Future<void> disconnect() => _method.invokeMethod('disconnect');

  /// ต้องเรียกหลังเชื่อมต่อทุกครั้ง: ความดัน/แคลอรี่คำนวณจากข้อมูลนี้
  Future<void> syncProfile(UserProfile p) =>
      _run(() => _method.invokeMethod('syncProfile', p.toMap()));

  Future<Map<String, dynamic>> readBattery() => _run(() async {
        final f = eventsOf('battery').first.timeout(const Duration(seconds: 10));
        await _method.invokeMethod('readBattery');
        return f;
      });

  // ---------- วัดความดัน ----------
  /// [cuff] = true ใช้ปั๊มลมในสาย (ค่าแม่นกว่า, ใช้เวลา ~40-60 วินาที)
  /// ระหว่างวัดจะมี event 'bpProgress' และจบด้วย 'bpResult' หรือ 'bpError'
  Future<BpReading> measureBloodPressure({bool cuff = true}) => _run(() async {
        final done = events
            .firstWhere((e) => e['type'] == 'bpResult' || e['type'] == 'bpError')
            .timeout(const Duration(seconds: 120));
        await _method.invokeMethod('startBp', {'method': cuff ? 'cuff' : 'ppg'});
        final Map<String, dynamic> e;
        try {
          e = await done;
        } finally {
          await _method.invokeMethod('stopBp', {'method': cuff ? 'cuff' : 'ppg'});
        }
        if (e['type'] == 'bpError') {
          throw PlatformException(code: 'BP_${e['status']}', message: bpStatusThai(e['status'] as String));
        }
        return bpFromEvent(e);
      });

  Future<void> cancelBloodPressure({bool cuff = true}) =>
      _method.invokeMethod('stopBp', {'method': cuff ? 'cuff' : 'ppg'});

  static BpReading bpFromEvent(Map e) => BpReading(
        measuredAt: e['at'] != null ? parseWatchTime(e['at']) : DateTime.now(),
        systolic: (e['systolic'] ?? 0) as int,
        diastolic: (e['diastolic'] ?? 0) as int,
        pulse: e['pulse'] as int?,
        method: (e['method'] ?? 'ppg') as String,
        status: (e['status'] ?? 'SUCCESS') as String,
        credibility: e['credibility'] as int?,
        source: (e['source'] ?? 'live') as String,
      );

  // ---------- ECG ----------
  /// เริ่มวัด ECG: ผู้ใช้ต้องแตะนิ้วที่ขั้วนาฬิกา ~30-60 วินาที
  /// waveform สดมาทาง event 'ecgWave', ผลสรุปมาทาง 'ecgResult'
  Future<EcgRecord> measureEcg() => _run(() async {
        final done = events
            .firstWhere((e) => e['type'] == 'ecgResult' || e['type'] == 'ecgError')
            .timeout(const Duration(seconds: 150));
        await _method.invokeMethod('startEcg');
        final Map<String, dynamic> e;
        try {
          e = await done;
        } finally {
          await _method.invokeMethod('stopEcg');
        }
        if (e['type'] == 'ecgError') {
          throw PlatformException(code: 'ECG_${e['status']}', message: 'วัด ECG ไม่สำเร็จ (${e['status']})');
        }
        return EcgRecord(
          measuredAt: e['at'] != null ? parseWatchTime(e['at']) : DateTime.now(),
          durationSec: (e['duration'] ?? 0) as int,
          sampleRateHz: (e['sampleRate'] ?? 0) as int,
          avgHeartRate: e['aveHeart'] as int?,
          avgHrv: e['aveHrv'] as int?,
          avgQt: e['aveQt'] as int?,
          avgRespRate: e['aveResp'] as int?,
          waveform: List<int>.from((e['waveform'] ?? const []) as List),
        );
      });

  Future<void> cancelEcg() => _method.invokeMethod('stopEcg');

  // ---------- ดึงข้อมูลย้อนหลัง ----------
  /// อ่านข้อมูลทั้งหมดที่นาฬิกาเก็บไว้ (ปกติ 3 วันย้อนหลัง)
  /// ระหว่างอ่านมี event: syncProgress, vitals, sleep, bpResult(source=auto/watch)
  Future<void> syncHistory() => _run(() async {
        final done = eventsOf('syncDone').first.timeout(const Duration(minutes: 5));
        await _method.invokeMethod('syncHistory');
        await done;
      });

  /// อ่านผลที่ผู้ใช้กดวัดบนนาฬิกาเอง (รวมความดันปั๊มลม) หลังเวลาที่กำหนด
  Future<void> readWatchMeasurements(DateTime since) => _run(() async {
        final done = eventsOf('manualDone').first.timeout(const Duration(minutes: 2));
        await _method.invokeMethod(
            'readWatchMeasurements', {'since': since.millisecondsSinceEpoch ~/ 1000});
        await done;
      });
}

String bpStatusThai(String s) {
  const m = {
    'POSTURE_ERROR': 'ท่าทางไม่ถูกต้อง ให้วางแขนระดับหัวใจ',
    'LOOSE': 'สายหลวมเกินไป รัดสายให้แน่นขึ้น',
    'NOT_WEAR': 'ไม่ได้สวมนาฬิกา',
    'TIME_OUT': 'หมดเวลาวัด',
    'HEART_ERROR': 'จับชีพจรไม่ได้',
    'SLOW_DEFLATION': 'ปล่อยลมช้าผิดปกติ',
    'TOO_MUCH_PRESSURE': 'แรงดันสูงเกินกำหนด',
    'POOR_SIGNAL_QUALITY': 'สัญญาณไม่ดี',
    'NOT_REMAINING_STATIONARY': 'ขยับระหว่างวัด กรุณานั่งนิ่งๆ',
    'CHARGING': 'นาฬิกากำลังชาร์จ',
    'LOW_POWER': 'แบตเตอรี่ต่ำ',
    'LOW_BATTERY': 'แบตเตอรี่ต่ำ',
    'DEVICE_BUSY': 'นาฬิกากำลังทำงานอื่นอยู่',
    'BUSY': 'นาฬิกากำลังทำงานอื่นอยู่',
    'WEAR_OFF': 'ไม่ได้สวมนาฬิกา',
    'FAILED': 'วัดไม่สำเร็จ',
    'NO_FUNCTION': 'นาฬิการุ่นนี้ไม่รองรับ',
    'INTERRUPTED': 'ยกเลิกการวัด',
  };
  return m[s] ?? 'วัดไม่สำเร็จ ($s)';
}
