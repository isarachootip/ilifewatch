import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/sync_service.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_live_extension.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';

/// หน้าจอสั่งวัด ออกซิเจนในเลือด (SpO2), อุณหภูมิร่างกาย (°C) และ ชีพจรสด (bpm) จากนาฬิกา F520Pro จริง
class Spo2TempScreen extends StatefulWidget {
  const Spo2TempScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<Spo2TempScreen> createState() => _Spo2TempScreenState();
}

class _Spo2TempScreenState extends State<Spo2TempScreen> {
  final _watch = WatchService.instance;
  late int _tab = widget.initialTab; // 0 = SpO2, 1 = Temp, 2 = Heart Rate
  StreamSubscription? _progSub;
  bool _measuring = false;
  int _progress = 0;
  String? _resultText;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _measuring = true;
      _progress = 0;
      _resultText = null;
      _error = null;
    });
    _progSub = _watch.events.listen((e) {
      if (_tab == 0 && e['type'] == 'spo2Progress') {
        setState(() => _progress = ((e['progress'] ?? 0) as num).toInt().clamp(0, 100));
      } else if (_tab == 1 && e['type'] == 'tempProgress') {
        setState(() => _progress = ((e['progress'] ?? 0) as num).toInt().clamp(0, 100));
      }
    });
    try {
      final now = DateTime.now();
      if (_tab == 0) {
        final v = await _watch.measureSpo2();
        AppState.instance.setVital('spo2', v.toDouble(), at: now);
        setState(() => _resultText = '$v%');
        await SyncService.instance.uploadPayload(vitals: [VitalSample(now, 'spo2', v.toDouble()).toJson()]);
      } else if (_tab == 1) {
        final c = await _watch.measureTemperature();
        AppState.instance.setVital('temperature', c, at: now);
        setState(() => _resultText = '${c.toStringAsFixed(1)} °C');
        await SyncService.instance.uploadPayload(vitals: [VitalSample(now, 'temperature', c).toJson()]);
      } else {
        final hr = await _watch.measureHeartRate();
        AppState.instance.setVital('heart_rate', hr.toDouble(), at: now);
        setState(() => _resultText = '$hr bpm');
        await SyncService.instance.uploadPayload(vitals: [VitalSample(now, 'heart_rate', hr.toDouble()).toJson()]);
      }
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    } on TimeoutException {
      setState(() => _error = tr('timeout_error'));
    } finally {
      await _progSub?.cancel();
      if (mounted) setState(() => _measuring = false);
    }
  }

  Future<void> _cancel() async {
    if (_tab == 0) await _watch.cancelSpo2();
    if (_tab == 1) await _watch.cancelTemperature();
    if (_tab == 2) await _watch.cancelHeartRate();
    if (mounted) setState(() => _measuring = false);
  }

  @override
  void dispose() {
    _progSub?.cancel();
    if (_measuring) _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final currentVal = switch (_tab) {
      0 => _resultText ?? (s.latestSpo2 != null ? '${s.latestSpo2}%' : '--%'),
      1 => _resultText ?? (s.latestTemperature != null ? '${s.latestTemperature!.toStringAsFixed(1)} °C' : '-- °C'),
      _ => _resultText ?? (s.latestHeartRate != null ? '${s.latestHeartRate} bpm' : '-- bpm'),
    };
    final accent = switch (_tab) {
      0 => ILifeTheme.teal,
      1 => ILifeTheme.orange,
      _ => ILifeTheme.magenta,
    };

    return Scaffold(
      appBar: AppBar(title: Text(tr('spo2_screen_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(tr('spo2_tab_label')), icon: const Icon(Icons.water_drop_outlined)),
                ButtonSegment(value: 1, label: Text(tr('temp_tab_label')), icon: const Icon(Icons.thermostat_outlined)),
                ButtonSegment(value: 2, label: Text(tr('hr_tab_label')), icon: const Icon(Icons.favorite_border)),
              ],
              selected: {_tab},
              onSelectionChanged: _measuring
                  ? null
                  : (sel) => setState(() {
                        _tab = sel.first;
                        _resultText = null;
                        _error = null;
                      }),
            ),
            const SizedBox(height: 16),
            Text(tr('spo2_guide_text'), textAlign: TextAlign.center, style: const TextStyle(color: ILifeTheme.textSecondary)),
            const Spacer(),
            Center(
              child: SizedBox(
                width: 190,
                height: 190,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _measuring ? (_progress > 0 ? _progress / 100 : null) : 1.0,
                        strokeWidth: 12,
                        backgroundColor: accent.withAlpha(35),
                        color: accent,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _measuring && _progress > 0 ? '$_progress%' : currentVal,
                          style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: accent),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _measuring ? tr('measuring_stay_still') : tr('normal_spo2'),
                          style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
            ],
            const Spacer(),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: _measuring ? _cancel : _start,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(_measuring ? tr('cancel') : (_resultText == null ? tr('start_measure') : tr('measure_again'))),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
