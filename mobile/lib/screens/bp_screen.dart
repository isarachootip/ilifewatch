import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/sync_service.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'bp_category.dart';

/// วัดความดันจากแอป (ค่าเริ่มต้นใช้ปั๊มลมในสาย)
class BpScreen extends StatefulWidget {
  const BpScreen({super.key});

  @override
  State<BpScreen> createState() => _BpScreenState();
}

class _BpScreenState extends State<BpScreen> {
  final _watch = WatchService.instance;
  StreamSubscription? _progSub;
  bool _measuring = false;
  bool _cuff = true;
  int _progress = 0;
  int? _pressure;
  BpReading? _result;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _measuring = true;
      _progress = 0;
      _pressure = null;
      _result = null;
      _error = null;
    });
    _progSub = _watch.eventsOf('bpProgress').listen((e) {
      setState(() {
        _progress = ((e['progress'] ?? 0) as num).toInt().clamp(0, 100);
        _pressure = (e['pressure'] as num?)?.toInt();
      });
    });
    try {
      final r = await _watch.measureBloodPressure(cuff: _cuff);
      AppState.instance.addBp(r);
      setState(() => _result = r);
      await SyncService.instance.uploadPayload(bp: [r.toJson()]);
    } on PlatformException catch (e) {
      setState(() => _error = e.message);
    } on TimeoutException {
      setState(() => _error = tr('timeout_error'));
    } finally {
      await _progSub?.cancel();
      if (mounted) setState(() => _measuring = false);
    }
  }

  @override
  void dispose() {
    _progSub?.cancel();
    if (_measuring) _watch.cancelBloodPressure(cuff: _cuff);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tr('bp_screen_title'))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_measuring && _result == null) ...[
            Text(tr('before_measure'), style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(tr('bp_guide_text')),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _cuff,
              onChanged: (v) => setState(() => _cuff = v),
              title: Text(tr('use_cuff_title')),
              subtitle: Text(tr('use_cuff_sub')),
            ),
          ],
          const Spacer(),
          if (_measuring) ...[
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(alignment: Alignment.center, children: [
                  SizedBox.expand(child: CircularProgressIndicator(value: _progress > 0 ? _progress / 100 : null, strokeWidth: 10)),
                  Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$_progress%', style: t.headlineMedium),
                    if (_pressure != null) Text('${tr('pressure_mmhg')} $_pressure mmHg'),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text(tr('measuring_stay_still'), textAlign: TextAlign.center),
          ],
          if (_result != null) _ResultView(r: _result!),
          if (_error != null)
            Text(_error!, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          const Spacer(),
          FilledButton(
            onPressed: _measuring ? () => _watch.cancelBloodPressure(cuff: _cuff) : _start,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_measuring ? tr('cancel') : (_result == null ? tr('start_measure') : tr('measure_again'))),
            ),
          ),
        ]),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({required this.r});
  final BpReading r;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = BpCategory.of(r.systolic, r.diastolic);
    return Column(children: [
      Text('${r.systolic}/${r.diastolic}', style: t.displayMedium?.copyWith(fontWeight: FontWeight.bold)),
      const Text('mmHg'),
      if (r.pulse != null && r.pulse! > 0) Text('${tr('pulse_label')} ${r.pulse} ${tr('beats_per_min')}', style: t.titleMedium),
      const SizedBox(height: 10),
      Chip(label: Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.bold))),
      if (r.systolic >= 180 || r.diastolic >= 110)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(tr('bp_critical_warning'), textAlign: TextAlign.center),
        ),
    ]);
  }
}
