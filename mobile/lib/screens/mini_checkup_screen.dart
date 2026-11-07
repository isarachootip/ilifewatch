import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/app_language.dart';
import '../services/sync_service.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_live_extension.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'widgets/mini_checkup_grid.dart';

/// หน้าตรวจสุขภาพด่วนในปุ่มเดียว 60 วินาที (One-Tap Mini Checkup — Joeme Fit SDK 260626_new)
class MiniCheckupScreen extends StatefulWidget {
  const MiniCheckupScreen({super.key});

  static String titleFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ตรวจสุขภาพด่วนในปุ่มเดียว (60 วินาที)',
        AppLanguage.en => 'One-Tap 60s Health Checkup',
        AppLanguage.zh => '一键60秒微体检',
        AppLanguage.ar => 'الفحص الصحي الشامل بنقرة واحدة (60 ثانية)',
        AppLanguage.de => '60-Sek. Schnell-Checkup mit einem Tippen',
        AppLanguage.jawi => 'فمريقساءن كصيحتن فنتس 60 ساعت',
        AppLanguage.ru => 'Экспресс-осмотр за 60 секунд',
        AppLanguage.he => 'בדיקת בריאות מהירה ב-60 שניות',
      };

  static String subtitleFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'วัดความดัน · ชีพจร · SpO2 · อุณหภูมิ · ความเครียด · HRV พร้อมกัน',
        AppLanguage.en => 'Measures BP · Heart Rate · SpO2 · Temp · Stress · HRV together',
        AppLanguage.zh => '同时测量血压 · 心率 · 血氧 · 体温 · 压力 · HRV',
        AppLanguage.ar => 'قياس ضغط الدم · النبض · الأكسجين · الحرارة · التوتر · HRV معاً',
        AppLanguage.de => 'Misst Blutdruck · Puls · SpO2 · Temperatur · Stress · HRV gleichzeitig',
        AppLanguage.jawi => 'اوكور تكنن · نادي · SpO2 · سوهو · ستريس · HRV سرنتق',
        AppLanguage.ru => 'АД · Пульс · SpO2 · Температура · Стресс · ВСР одновременно',
        AppLanguage.he => 'מודד לחץ דם · דופק · SpO2 · חום · מתח · HRV במקביל',
      };

  static String watchHintFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ไฟเซนเซอร์ใต้เรือนนาฬิกากำลังทำงาน (หน้าจอนาฬิกาจะอยู่หน้าปกติ) กรุณาสวมให้กระชับและอยู่นิ่งๆ',
        AppLanguage.en => 'Watch rear optical sensors are active (watch screen stays on normal face). Keep wrist still.',
        AppLanguage.zh => '手表背部传感器指示灯已亮起（表盘保持正常界面），请佩戴紧贴并保持静止',
        AppLanguage.ar => 'مستشعر الساعة الخلفي يعمل الآن (تبقى شاشة الساعة عادية)، يرجى الثبات',
        AppLanguage.de => 'Rückseitige Sensoren der Uhr sind aktiv (Uhrdisplay bleibt normal). Bitte ruhig halten.',
        AppLanguage.jawi => 'سينسور بلاكڠ جم سدڠ برفوڠسي (سكرين جم ككل بياسا)، سيلا دودوق diam',
        AppLanguage.ru => 'Датчики на задней панели часов активны (экран часов остается обычным). Не двигайтесь.',
        AppLanguage.he => 'חיישני השעון האחוריים פועלים (מסך השעון נשאר רגיל). נא להישאר ללא תנועה.',
      };

  @override
  State<MiniCheckupScreen> createState() => _MiniCheckupScreenState();
}

class _MiniCheckupScreenState extends State<MiniCheckupScreen> {
  final _watch = WatchService.instance;
  StreamSubscription<Map<String, dynamic>>? _sub;
  bool _busy = false;
  bool _sessionStarted = false;
  int _progress = 0;
  int _stage = 0;
  String? _step, _error;
  Map<String, dynamic>? _result;

  static String _startBtn(AppLanguage l) => switch (l) {
        AppLanguage.th => 'เริ่มตรวจสุขภาพด่วน',
        AppLanguage.en => 'Start One-Tap Checkup',
        AppLanguage.zh => '开始一键微体检',
        AppLanguage.ar => 'بدء الفحص الشامل',
        AppLanguage.de => 'Schnell-Checkup starten',
        AppLanguage.jawi => 'مولا فمريقساءن فنتس',
        AppLanguage.ru => 'Начать экспресс-осмотр',
        AppLanguage.he => 'התחל בדיקה מהירה',
      };

  static String _stopBtn(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ยกเลิกการวัด',
        AppLanguage.en => 'Cancel Checkup',
        AppLanguage.zh => '停止测量',
        AppLanguage.ar => 'إلغاء الفحص',
        AppLanguage.de => 'Abbrechen',
        AppLanguage.jawi => 'بتل فمريقساءن',
        AppLanguage.ru => 'Отменить',
        AppLanguage.he => 'בטל בדיקה',
      };

  @override
  void initState() {
    super.initState();
    _sub = _watch.eventsOf('miniCheckupProgress').listen((e) {
      if (!mounted) return;
      setState(() {
        _progress = (e['progress'] as num?)?.toInt() ?? _progress;
        _stage = (e['stage'] as num?)?.toInt() ?? (_progress <= 25 ? 1 : _progress <= 55 ? 2 : _progress <= 84 ? 3 : 4);
        _step = (e['step'] as String?) ?? _step;
        final cur = Map<String, dynamic>.from(_result ?? const {});
        for (final k in ['heartRate', 'spo2', 'systolic', 'diastolic', 'temperature', 'stress', 'hrv']) {
          if (e[k] != null) cur[k] = e[k];
        }
        _result = cur;
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    if (_busy) _watch.cancelMiniCheckup();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() { _busy = true; _sessionStarted = true; _progress = 0; _stage = 1; _result = {}; _step = 'กำลังเริ่มตรวจสุขภาพด่วน...'; _error = null; });
    try {
      final res = await _watch.runMiniCheckup();
      final now = DateTime.now(), utc = now.toUtc(), s = AppState.instance;
      final vitals = <Map<String, dynamic>>[], bpList = <Map<String, dynamic>>[];
      final hr = (res['heartRate'] as num?)?.toInt() ?? 0, spo2 = (res['spo2'] as num?)?.toInt() ?? 0;
      final sys = (res['systolic'] as num?)?.toInt() ?? 0, dia = (res['diastolic'] as num?)?.toInt() ?? 0;
      final temp = (res['temperature'] as num?)?.toDouble();
      final stress = (res['stress'] as num?)?.toInt() ?? 0, hrv = (res['hrv'] as num?)?.toInt() ?? 0;

      if (hr > 0) { s.setVital('heart_rate', hr.toDouble(), at: now); vitals.add(VitalSample(utc, 'heart_rate', hr.toDouble()).toJson()); }
      if (spo2 > 0) { s.setVital('spo2', spo2.toDouble(), at: now); vitals.add(VitalSample(utc, 'spo2', spo2.toDouble()).toJson()); }
      if (temp != null && temp > 30) { s.setVital('temperature', temp, at: now); vitals.add(VitalSample(utc, 'temperature', temp).toJson()); }
      if (stress > 0) { s.setVital('stress', stress.toDouble(), at: now); vitals.add(VitalSample(utc, 'stress', stress.toDouble()).toJson()); }
      if (hrv > 0) { s.setVital('hrv', hrv.toDouble(), at: now); vitals.add(VitalSample(utc, 'hrv', hrv.toDouble()).toJson()); }
      if (sys > 0 && dia > 0) {
        final bp = BpReading(measuredAt: utc, systolic: sys, diastolic: dia, pulse: hr > 0 ? hr : null, method: (res['bpMethod'] as String?) ?? 'ppg', status: 'SUCCESS', source: 'live');
        s.addBp(bp); bpList.add(bp.toJson());
      }
      await SyncService.instance.uploadPayload(bp: bpList, vitals: vitals);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      if (mounted && !(e is PlatformException && e.code == 'CHECKUP_INTERRUPTED')) {
        setState(() => _error = e is PlatformException ? (e.message ?? e.code) : '$e');
      }
    } finally {
      if (mounted) setState(() { _busy = false; _stage = 0; _step = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppState.instance.language, s = AppState.instance;
    final sys = (_result?['systolic'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestBp?.systolic), dia = (_result?['diastolic'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestBp?.diastolic);
    final hr = (_result?['heartRate'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestHeartRate), spo2 = (_result?['spo2'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestSpo2);
    final temp = (_result?['temperature'] as num?)?.toDouble() ?? (_sessionStarted ? null : s.latestTemperature);
    final stress = (_result?['stress'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestStress), hrv = (_result?['hrv'] as num?)?.toInt() ?? (_sessionStarted ? null : s.latestHrv);

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
                  if (_step != null) Text(_step!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text(MiniCheckupScreen.watchHintFor(l), textAlign: TextAlign.center, style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85))),
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
          if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600))),
          const SizedBox(height: 18),
          MiniCheckupGrid(
            language: l, busy: _busy, activeStage: _stage,
            systolic: sys, diastolic: dia, heartRate: hr, spo2: spo2, temperature: temp, stress: stress, hrv: hrv,
          ),
        ],
      ),
    );
  }
}
