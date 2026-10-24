import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_strings.dart';
import '../services/sync_service.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';

/// วัด ECG และแสดงคลื่นแบบสด
/// ผลสรุปที่แสดงคือค่าทั่วไป (ชีพจร, HRV, QT) — ไม่แสดงผลวินิจฉัยโรค
/// waveform ทั้งหมดถูกส่งขึ้นเซิร์ฟเวอร์ให้แพทย์/เจ้าหน้าที่ดูได้
class EcgScreen extends StatefulWidget {
  const EcgScreen({super.key});

  @override
  State<EcgScreen> createState() => _EcgScreenState();
}

class _EcgScreenState extends State<EcgScreen> {
  final _watch = WatchService.instance;
  final _points = <int>[];
  static const _window = 1500; // จำนวนจุดที่แสดงบนจอ
  StreamSubscription? _waveSub, _progSub;
  bool _measuring = false;
  bool _leadOff = false;
  int _progress = 0;
  int? _hr;
  EcgRecord? _result;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _measuring = true;
      _points.clear();
      _result = null;
      _error = null;
      _progress = 0;
    });
    _waveSub = _watch.eventsOf('ecgWave').listen((e) {
      _points.addAll(List<int>.from(e['samples'] as List));
      if (_points.length > _window) _points.removeRange(0, _points.length - _window);
      setState(() {});
    });
    _progSub = _watch.eventsOf('ecgProgress').listen((e) {
      setState(() {
        _progress = ((e['progress'] ?? 0) as num).toInt().clamp(0, 100);
        _leadOff = e['leadOff'] == true;
        final hr = (e['heartRate'] as num?)?.toInt();
        if (hr != null && hr > 0) _hr = hr;
      });
    });
    try {
      final r = await _watch.measureEcg();
      setState(() => _result = r);
      await SyncService.instance.uploadPayload(ecg: [
        {...r.toJson(), 'source': 'live'}
      ]);
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    } on TimeoutException {
      setState(() => _error = tr('timeout_error'));
    } finally {
      await _waveSub?.cancel();
      await _progSub?.cancel();
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  void dispose() {
    _waveSub?.cancel();
    _progSub?.cancel();
    if (_measuring) _watch.cancelEcg();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('ecg_screen_title'))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(tr('ecg_guide_text')),
          const SizedBox(height: 12),
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8F8),
              border: Border.all(color: const Color(0xFFF2B8B5)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: CustomPaint(painter: EcgPainter(_result?.waveform.take(_window).toList() ?? _points)),
          ),
          const SizedBox(height: 12),
          if (_measuring) ...[
            LinearProgressIndicator(value: _progress > 0 ? _progress / 100 : null),
            const SizedBox(height: 6),
            Text(
              _leadOff
                  ? tr('ecg_lead_off')
                  : '${tr('measuring_pct')} $_progress%${_hr != null ? ' · ${tr('pulse_label')} $_hr' : ''}',
              style: _leadOff ? TextStyle(color: Theme.of(context).colorScheme.error) : null,
            ),
          ],
          if (_result != null) ...[
            Text(tr('measure_done'), style: t.titleLarge),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _chip(tr('avg_pulse'), _result!.avgHeartRate, tr('beats_per_min')),
              _chip('HRV', _result!.avgHrv, 'ms'),
              _chip('QT', _result!.avgQt, 'ms'),
              _chip(tr('resp_rate'), _result!.avgRespRate, tr('beats_per_min')),
            ]),
            const SizedBox(height: 8),
            Text(tr('ecg_sent_note')),
          ],
          if (_error != null)
            Text(_error!, style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          const Spacer(),
          FilledButton(
            onPressed: _measuring ? () => _watch.cancelEcg() : _start,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_measuring ? tr('stop') : (_result == null ? tr('start_measure') : tr('measure_again'))),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _chip(String label, int? v, String unit) =>
      Chip(label: Text('$label ${v != null && v > 0 ? '$v $unit' : '-'}'));
}

class EcgPainter extends CustomPainter {
  EcgPainter(this.points);
  final List<int> points;

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = const Color(0xFFF6D3D1)
      ..strokeWidth = 0.5;
    for (double x = 0; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 20) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (points.length < 2) return;

    var lo = points.reduce(math.min).toDouble();
    var hi = points.reduce(math.max).toDouble();
    if (hi - lo < 1) hi = lo + 1;
    final pad = (hi - lo) * 0.1;
    lo -= pad;
    hi += pad;
    final dx = size.width / (points.length - 1);
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * dx;
      final y = size.height - (points[i] - lo) / (hi - lo) * size.height;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFB3261E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant EcgPainter oldDelegate) => true;
}
