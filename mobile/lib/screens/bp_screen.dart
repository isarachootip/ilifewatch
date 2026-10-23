import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_state.dart';
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
      setState(() => _error = 'หมดเวลาวัด ลองใหม่อีกครั้ง');
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
      appBar: AppBar(title: const Text('วัดความดัน')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (!_measuring && _result == null) ...[
            const Text('ก่อนวัด:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            const Text('• นั่งพัก 5 นาที หลังพิงพนัก เท้าวางราบ\n'
                '• รัดสายนาฬิกาให้กระชับ ถุงลมอยู่ด้านในข้อมือ\n'
                '• วางแขนบนโต๊ะ ยกข้อมือให้อยู่ระดับหัวใจ\n'
                '• อยู่นิ่งๆ ไม่พูดคุยระหว่างวัด (ประมาณ 1 นาที)'),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _cuff,
              onChanged: (v) => setState(() => _cuff = v),
              title: const Text('ใช้ปั๊มลม (แนะนำ)'),
              subtitle: const Text('ปิดเพื่อใช้เซนเซอร์แสง ซึ่งเร็วกว่าแต่แม่นยำน้อยกว่า'),
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
                    if (_pressure != null) Text('แรงดัน $_pressure mmHg'),
                  ]),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            const Text('กำลังวัด... กรุณาอยู่นิ่งๆ', textAlign: TextAlign.center),
          ],
          if (_result != null) _ResultView(r: _result!),
          if (_error != null)
            Text(_error!, textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
          const Spacer(),
          FilledButton(
            onPressed: _measuring ? () => _watch.cancelBloodPressure(cuff: _cuff) : _start,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(_measuring ? 'ยกเลิก' : (_result == null ? 'เริ่มวัด' : 'วัดอีกครั้ง')),
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
      if (r.pulse != null && r.pulse! > 0) Text('ชีพจร ${r.pulse} ครั้ง/นาที', style: t.titleMedium),
      const SizedBox(height: 10),
      Chip(label: Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.bold))),
      if (r.systolic >= 180 || r.diastolic >= 110)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('ค่าสูงมาก: นั่งพัก 5 นาทีแล้ววัดซ้ำ หากยังสูงหรือมีอาการ เช่น ปวดศีรษะรุนแรง เจ็บหน้าอก '
              'แขนขาอ่อนแรง ให้ติดต่อแพทย์หรือโทร 1669 ทันที', textAlign: TextAlign.center),
        ),
    ]);
  }
}
