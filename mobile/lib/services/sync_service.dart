import 'dart:async';

import '../app_state.dart';
import '../data/upload_queue.dart';
import '../watch/watch_live_extension.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';

/// ขั้นตอนมาตรฐานหลังเชื่อมต่อนาฬิกา:
///   1) ส่งข้อมูลส่วนตัว (จำเป็นต่อการคำนวณความดัน/แคลอรี่)
///   2) อ่านผลที่ผู้ใช้กดวัดบนนาฬิกาเอง (รวมความดันปั๊มลม)
///   3) อ่านข้อมูลย้อนหลังอัตโนมัติ (ชีพจร SpO2 การนอน ความดันอัตโนมัติ)
///   4) ส่งขึ้นเซิร์ฟเวอร์ (ถ้าไม่มีเน็ต เก็บไว้ในคิว)
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _watch = WatchService.instance;
  final _queue = UploadQueue();
  final _state = AppState.instance;
  bool _running = false;

  /// ความคืบหน้า 0..1 สำหรับแสดงบนหน้าจอ
  final progress = StreamController<double>.broadcast();

  Future<void> afterConnect() async {
    final p = _state.profile;
    if (p != null) await _watch.syncProfile(p);
    try {
      _state.setBattery(await _watch.readBattery());
      final sp = await _watch.readCurrentSportStep();
      final steps = (sp['steps'] as num?)?.toInt();
      if (steps != null && steps > 0) _state.setTodaySteps(steps);
    } catch (_) {}
    await syncAll();
  }

  Future<void> syncAll() async {
    if (_running) return;
    _running = true;
    _state.resetStepsForSync();
    final bp = <Map<String, dynamic>>[];
    final ecg = <Map<String, dynamic>>[];
    final vitals = <Map<String, dynamic>>[];
    final sleep = <Map<String, dynamic>>[];

    final sub = _watch.events.listen((e) {
      switch (e['type']) {
        case 'bpResult':
          final r = WatchService.bpFromEvent(e);
          if (r.isValid) {
            bp.add(r.toJson());
            _state.addBp(r);
          }
          break;
        case 'ecgResult':
          ecg.add({
            'measured_at': parseWatchTime(e['at']).toUtc().toIso8601String(),
            'duration_sec': e['duration'],
            'sample_rate_hz': e['sampleRate'],
            'avg_heart_rate': e['aveHeart'],
            'avg_hrv': e['aveHrv'],
            'avg_qt': e['aveQt'],
            'avg_resp_rate': e['aveResp'],
            'waveform': e['waveform'],
            'source': e['source'] ?? 'watch',
          });
          break;
        case 'vitals':
          for (final s in (e['samples'] as List)) {
            final m = Map<String, dynamic>.from(s as Map);
            final at = parseWatchTime(m['at']);
            final v = VitalSample(at, m['metric'] as String, (m['value'] as num).toDouble());
            vitals.add(v.toJson());
            _state.setVital(v.metric, v.value, at: at.toLocal());
          }
          break;
        case 'sleep':
          final deep = (e['deep'] ?? 0) as int;
          final light = (e['light'] ?? 0) as int;
          _state.setSleep(deep: deep, light: light);
          sleep.add(SleepSession(
            start: parseWatchTime(e['start']),
            end: parseWatchTime(e['end']),
            deepMinutes: deep,
            lightMinutes: light,
            wakeCount: (e['wake'] ?? 0) as int,
            quality: e['quality'] as int?,
            curve: e['curve'] as String?,
          ).toJson());
          break;
        case 'syncProgress':
          progress.add((e['progress'] as num).toDouble());
          break;
      }
    });

    final started = DateTime.now();
    try {
      final since = _state.lastSync?.subtract(const Duration(hours: 1)) ??
          DateTime.now().subtract(const Duration(days: 7));
      await _watch.readWatchMeasurements(since);
      await _watch.syncHistory();
      await Future<void>.delayed(const Duration(milliseconds: 300));
    } finally {
      await sub.cancel();
      _running = false;
    }

    if (_state.isLoggedIn) {
      await uploadPayload(bp: bp, ecg: ecg, vitals: vitals, sleep: sleep);
    }
    await _state.markSynced(started);
    progress.add(1.0);
  }

  /// ส่งผลวัดครั้งเดียว (เช่น หลังวัดความดันจากแอป)
  Future<void> uploadPayload({
    List<Map<String, dynamic>> bp = const [],
    List<Map<String, dynamic>> ecg = const [],
    List<Map<String, dynamic>> vitals = const [],
    List<Map<String, dynamic>> sleep = const [],
  }) async {
    if (!_state.isLoggedIn) return;
    if (bp.isEmpty && ecg.isEmpty && vitals.isEmpty && sleep.isEmpty) {
      _state.addAlerts(await _queue.flush(_state.api));
      return;
    }
    final info = _watch.deviceInfo;
    await _queue.add({
      'device': {
        'mac': info?['mac'] ?? _state.pairedMac,
        'firmware': info?['firmware'],
        'model': 'F520Pro',
      },
      'bp': bp,
      'ecg': ecg,
      'vitals': vitals,
      'sleep': sleep,
    });
    _state.addAlerts(await _queue.flush(_state.api));
  }
}
