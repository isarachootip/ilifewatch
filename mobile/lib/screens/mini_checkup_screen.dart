import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/app_language.dart';
import '../services/sync_service.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_live_extension.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';

/// หน้าตรวจสุขภาพด่วนในปุ่มเดียว 60 วินาที (One-Tap Mini Checkup — Joeme Fit SDK 260626_new)
class MiniCheckupScreen extends StatefulWidget {
  const MiniCheckupScreen({super.key});

  static String titleFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ตรวจสุขภาพด่วนในปุ่มเดียว (60 วินาที)',
        AppLanguage.en => 'One-Tap 60s Health Checkup',
        AppLanguage.zh => '一键60秒微体检',
        AppLanguage.ar => 'الفحص الصحي الشامل بنقرة واحدة (60 ثانية)',
        AppLanguage.de => '60-Sek. Schnell-Checkup mit einem Tippen',
      };

  static String subtitleFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'วัดความดัน · ชีพจร · SpO2 · อุณหภูมิ · ความเครียด · HRV พร้อมกัน',
        AppLanguage.en => 'Measures BP · Heart Rate · SpO2 · Temp · Stress · HRV together',
        AppLanguage.zh => '同时测量血压 · 心率 · 血氧 · 体温 · 压力 · HRV',
        AppLanguage.ar => 'قياس ضغط الدم · النبض · الأكسجين · الحرارة · التوتر · HRV معاً',
        AppLanguage.de => 'Misst Blutdruck · Puls · SpO2 · Temperatur · Stress · HRV gleichzeitig',
      };

  @override
  State<MiniCheckupScreen> createState() => _MiniCheckupScreenState();
}

class _MiniCheckupScreenState extends State<MiniCheckupScreen> {
  final _watch = WatchService.instance;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _busy = false;
  int _progress = 0;
  String? _error;
  Map<String, dynamic>? _result;

  static String _startBtn(AppLanguage l) => switch (l) {
        AppLanguage.th => 'เริ่มตรวจสุขภาพด่วน',
        AppLanguage.en => 'Start One-Tap Checkup',
        AppLanguage.zh => '开始一键微体检',
        AppLanguage.ar => 'بدء الفحص الشامل',
        AppLanguage.de => 'Schnell-Checkup starten',
      };

  static String _stopBtn(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ยกเลิกการวัด',
        AppLanguage.en => 'Cancel Checkup',
        AppLanguage.zh => '停止测量',
        AppLanguage.ar => 'إلغاء الفحص',
        AppLanguage.de => 'Abbrechen',
      };

  @override
  void initState() {
    super.initState();
    _sub = _watch.eventsOf('miniCheckupProgress').listen((e) {
      if (mounted) setState(() => _progress = (e['progress'] as num?)?.toInt() ?? _progress);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_busy) _watch.cancelMiniCheckup();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _busy = true; _progress = 0; _error = null; });
    try {
      final res = await _watch.runMiniCheckup();
      final now = DateTime.now(), utc = now.toUtc(), s = AppState.instance;
      final vitals = <Map<String, dynamic>>[], bpList = <Map<String, dynamic>>[];
      final hr = (res['heartRate'] as num?)?.toInt() ?? 0;
      final spo2 = (res['spo2'] as num?)?.toInt() ?? 0;
      final sys = (res['systolic'] as num?)?.toInt() ?? 0;
      final dia = (res['diastolic'] as num?)?.toInt() ?? 0;
      final temp = (res['temperature'] as num?)?.toDouble();
      final stress = (res['stress'] as num?)?.toInt() ?? 0;
      final hrv = (res['hrv'] as num?)?.toInt() ?? 0;

      if (hr > 0) { s.setVital('heart_rate', hr.toDouble(), at: now); vitals.add(VitalSample(utc, 'heart_rate', hr.toDouble()).toJson()); }
      if (spo2 > 0) { s.setVital('spo2', spo2.toDouble(), at: now); vitals.add(VitalSample(utc, 'spo2', spo2.toDouble()).toJson()); }
      if (temp != null && temp > 30) { s.setVital('temperature', temp, at: now); vitals.add(VitalSample(utc, 'temperature', temp).toJson()); }
      if (stress > 0) vitals.add(VitalSample(utc, 'stress', stress.toDouble()).toJson());
      if (hrv > 0) vitals.add(VitalSample(utc, 'hrv', hrv.toDouble()).toJson());
      if (sys > 0 && dia > 0) {
        final bp = BpReading(
          measuredAt: utc, systolic: sys, diastolic: dia, pulse: hr > 0 ? hr : null,
          method: (res['bpMethod'] as String?) ?? 'ppg', status: 'SUCCESS', source: 'live',
        );
        s.addBp(bp);
        bpList.add(bp.toJson());
      }
      await SyncService.instance.uploadPayload(bp: bpList, vitals: vitals);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppState.instance.language, s = AppState.instance;
    final sys = (_result?['systolic'] as num?)?.toInt() ?? s.latestBp?.systolic;
    final dia = (_result?['diastolic'] as num?)?.toInt() ?? s.latestBp?.diastolic;
    final hr = (_result?['heartRate'] as num?)?.toInt() ?? s.latestHeartRate;
    final spo2 = (_result?['spo2'] as num?)?.toInt() ?? s.latestSpo2;
    final temp = (_result?['temperature'] as num?)?.toDouble() ?? s.latestTemperature;
    final stress = (_result?['stress'] as num?)?.toInt();
    final hrv = (_result?['hrv'] as num?)?.toInt();

    return Scaffold(
      appBar: AppBar(title: Text(MiniCheckupScreen.titleFor(l))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [ILifeTheme.magenta, ILifeTheme.navy]),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                const Icon(Icons.health_and_safety, size: 52, color: Colors.white),
                const SizedBox(height: 10),
                Text(MiniCheckupScreen.titleFor(l), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white)),
                const SizedBox(height: 6),
                Text(MiniCheckupScreen.subtitleFor(l), textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9))),
                if (_busy) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _progress > 0 ? _progress / 100 : null, backgroundColor: Colors.white24, color: Colors.white, minHeight: 8),
                  const SizedBox(height: 8),
                  Text('$_progress%', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: ILifeTheme.magenta),
                  onPressed: _busy ? () => _watch.cancelMiniCheckup() : _start,
                  icon: Icon(_busy ? Icons.stop : Icons.play_arrow_rounded),
                  label: Text(_busy ? _stopBtn(l) : _startBtn(l)),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 1.55,
            children: [
              _tile('BP (mmHg)', sys != null && dia != null ? '$sys/$dia' : '--/--', Icons.speed, ILifeTheme.magenta),
              _tile('Heart Rate', hr != null ? '$hr bpm' : '-- bpm', Icons.favorite, const Color(0xFFE53935)),
              _tile('SpO2', spo2 != null ? '$spo2%' : '--%', Icons.air, ILifeTheme.teal),
              _tile('Body Temp', temp != null ? '${temp.toStringAsFixed(1)} °C' : '--.- °C', Icons.thermostat, const Color(0xFFFB8C00)),
              _tile('Stress', stress != null && stress > 0 ? '$stress' : '--', Icons.psychology_alt, ILifeTheme.navy),
              _tile('HRV', hrv != null && hrv > 0 ? '$hrv ms' : '-- ms', Icons.monitor_heart_outlined, const Color(0xFF8E24AA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tile(String label, String value, IconData icon, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [Icon(icon, size: 18, color: color), const SizedBox(width: 6), Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)))]),
            Text(value, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color)),
          ],
        ),
      );
}
