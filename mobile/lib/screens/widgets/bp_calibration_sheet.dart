import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/app_language.dart';
import '../../theme/ilife_theme.dart';
import '../../watch/watch_live_extension.dart';
import '../../watch/watch_models.dart';
import '../../watch/watch_service.dart';

/// แผ่นตั้งค่าการปรับเทียบความดันโลหิตเฉพาะบุคคล (Personal BP Calibration — Private Mode)
Future<void> showBpCalibrationSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
    builder: (_) => const _BpCalibrationSheet(),
  );
}

class _BpCalibrationSheet extends StatefulWidget {
  const _BpCalibrationSheet();

  @override
  State<_BpCalibrationSheet> createState() => _BpCalibrationSheetState();
}

class _BpCalibrationSheetState extends State<_BpCalibrationSheet> {
  late bool _privateMode = AppState.instance.bpPrivateMode;
  late final _sys = TextEditingController(text: '${AppState.instance.bpCalSystolic}');
  late final _dia = TextEditingController(text: '${AppState.instance.bpCalDiastolic}');
  bool _saving = false;
  String? _msg;

  static String titleFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'ปรับเทียบความดันเฉพาะบุคคล (BP Calibration)',
        AppLanguage.en => 'Personal BP Calibration (Private Mode)',
        AppLanguage.zh => '私人血压校准 (Private Mode)',
        AppLanguage.ar => 'معايرة ضغط الدم الشخصية',
        AppLanguage.de => 'Persönliche Blutdruck-Kalibrierung',
        AppLanguage.jawi => 'كاليبراسي تكنن داره فريبادي',
        AppLanguage.ru => 'Индивидуальная калибровка АД',
        AppLanguage.he => 'כיול לחץ דם אישי (מצב פרטי)',
      };

  static String descFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'กรอกค่าความดันตัวบน/ตัวล่างที่วัดจากเครื่องมาตรฐานของโรงพยาบาล เพื่อปรับเทียบเซนเซอร์บนนาฬิกา F520Pro',
        AppLanguage.en => 'Enter reference Systolic/Diastolic values from a clinical cuff monitor to calibrate your F520Pro watch.',
        AppLanguage.zh => '输入医院标准血压计测得的收缩压/舒张压，以校准 F520Pro 手表传感器。',
        AppLanguage.ar => 'أدخل قيم الضغط الانقباضي/الانبساطي المرجعية من جهاز المستشفى لمعايرة ساعة F520Pro.',
        AppLanguage.de => 'Referenzwerte (Systolisch/Diastolisch) eines klinischen Messgeräts zur Kalibrierung der F520Pro eingeben.',
        AppLanguage.jawi => 'ماسوقكن باچاءن تكنن داره دري مسين هوسفيتل اونتوق كاليبراسي جام F520Pro.',
        AppLanguage.ru => 'Введите эталонные значения АД с медицинского тонометра для калибровки часов F520Pro.',
        AppLanguage.he => 'הזן ערכי לחץ דם סיסטולי/דיאסטולי ממכשיר רפואי לכיול שעון ה-F520Pro.',
      };

  Future<void> _save() async {
    final sys = int.tryParse(_sys.text.trim()) ?? 120;
    final dia = int.tryParse(_dia.text.trim()) ?? 80;
    if (sys < 60 || sys > 260 || dia < 30 || dia > 180 || sys <= dia) {
      setState(() => _msg = 'กรุณากรอกค่าที่ถูกต้อง (เช่น 120 / 80 mmHg)');
      return;
    }
    setState(() { _saving = true; _msg = null; });
    try {
      await AppState.instance.setBpCalibration(privateMode: _privateMode, systolic: sys, diastolic: dia);
      if (WatchService.instance.state == WatchConnection.ready) {
        await WatchService.instance.configureBpCalibration(privateMode: _privateMode, systolic: sys, diastolic: dia);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => _msg = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppState.instance.language;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titleFor(l), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
        const SizedBox(height: 6),
        Text(descFor(l), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _privateMode,
          onChanged: (v) => setState(() => _privateMode = v),
          title: const Text('เปิดใช้โหมดปรับเทียบเฉพาะบุคคล (Private Mode)', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        Row(children: [
          Expanded(child: TextField(controller: _sys, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Systolic (mmHg)', border: OutlineInputBorder()))),
          const SizedBox(width: 12),
          Expanded(child: TextField(controller: _dia, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diastolic (mmHg)', border: OutlineInputBorder()))),
        ]),
        if (_msg != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_msg!, style: const TextStyle(color: Colors.redAccent))),
        const SizedBox(height: 16),
        FilledButton(onPressed: _saving ? null : _save, child: Padding(padding: const EdgeInsets.all(12), child: Text(_saving ? '...' : 'บันทึกและส่งค่าลงนาฬิกา F520Pro'))),
      ]),
    );
  }
}
