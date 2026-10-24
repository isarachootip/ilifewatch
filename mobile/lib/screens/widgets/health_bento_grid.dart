import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../theme/ilife_theme.dart';
import '../bp_category.dart';
import '../home_widgets.dart';

/// ตารางการ์ดสุขภาพ 2 คอลัมน์ (Bento Grid) สไตล์ Huawei Health
class HealthBentoGrid extends StatelessWidget {
  const HealthBentoGrid({
    super.key,
    required this.state,
    required this.onMeasureBp,
    required this.onMeasureEcg,
    required this.onOpenExercise,
  });

  final AppState state;
  final VoidCallback onMeasureBp;
  final VoidCallback onMeasureEcg;
  final VoidCallback onOpenExercise;

  @override
  Widget build(BuildContext context) {
    final bp = state.latestBp;
    final bpCat = bp != null ? BpCategory.of(bp.systolic, bp.diastolic) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BentoCard(
                title: 'บันทึกการออกกำลังกาย',
                onTap: onOpenExercise,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: ILifeTheme.navy),
                        children: [
                          TextSpan(
                            text: state.distanceKm.toStringAsFixed(2),
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                          ),
                          const TextSpan(text: ' กม.', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: (state.todaySteps / 6000).clamp(0.08, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFFE0F2F1),
                        color: const Color(0xFF26C6DA),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text('เผาผลาญ ${state.caloriesKcal} kcal', style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                    const SizedBox(height: 4),
                    const Text('🏃 อยู่ในแผนสุขภาพดี >', style: TextStyle(fontSize: 12, color: ILifeTheme.orange, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: 'ความดันโลหิต (ปั๊มลม)',
                onTap: onMeasureBp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bp != null ? '${bp.systolic}/${bp.diastolic}' : 'กดเพื่อวัด',
                      style: TextStyle(
                        fontSize: bp != null ? 24 : 18,
                        fontWeight: FontWeight.w900,
                        color: bpCat?.color ?? ILifeTheme.magenta,
                      ),
                    ),
                    Text(
                      bp != null ? 'mmHg · ${bpCat!.label}' : 'ถุงลม F520Pro',
                      style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.favorite, size: 16, color: bpCat?.color ?? ILifeTheme.magenta),
                        const SizedBox(width: 4),
                        Text(
                          bp?.pulse != null ? 'ชีพจร ${bp!.pulse} bpm' : 'แตะเพื่อเริ่มวัดทันที >',
                          style: const TextStyle(fontSize: 12, color: ILifeTheme.magenta, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BentoCard(
                title: 'คลื่นหัวใจ & ชีพจร',
                onTap: onMeasureEcg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.latestHeartRate != null ? '${state.latestHeartRate} bpm' : '-- bpm',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ILifeTheme.navy),
                    ),
                    const SizedBox(height: 4),
                    const Text('วัดกราฟ ECG สด 30 วินาที', style: TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('📈 เริ่มวัดคลื่น ECG >', style: TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BentoCard(
                title: 'ออกซิเจนในเลือด (SpO2)',
                onTap: onMeasureBp,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.latestSpo2 != null ? '${state.latestSpo2}%' : '--%',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ILifeTheme.navy),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      state.latestTemperature != null
                          ? 'อุณหภูมิ ${state.latestTemperature!.toStringAsFixed(1)} °C'
                          : 'ซิงค์อัตโนมัติจาก F520Pro',
                      style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    const Text('💧 เกณฑ์ปกติ ≥ 95%', style: TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (state.recentBp.isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ประวัติความดันล่าสุด', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                  const SizedBox(height: 8),
                  ...state.recentBp.take(5).map((r) {
                    final c = BpCategory.of(r.systolic, r.diastolic);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(backgroundColor: c.color, radius: 6),
                      title: Text('${r.systolic}/${r.diastolic} mmHg${r.pulse != null ? ' · ชีพจร ${r.pulse}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${formatShortDateTime(r.measuredAt)} · ${r.method == 'cuff' ? 'ปั๊มลม' : 'เซนเซอร์แสง'}'),
                      trailing: Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.w700)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BentoCard extends StatelessWidget {
  const _BentoCard({required this.title, required this.child, required this.onTap});
  final String title;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
