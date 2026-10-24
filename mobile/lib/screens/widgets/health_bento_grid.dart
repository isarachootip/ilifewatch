import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/app_strings.dart';
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
    required this.onMeasureSpo2,
    required this.onOpenExercise,
  });

  final AppState state;
  final VoidCallback onMeasureBp, onMeasureEcg, onMeasureSpo2, onOpenExercise;

  @override
  Widget build(BuildContext context) {
    final bp = state.latestBp;
    final bpCat = bp != null ? BpCategory.of(bp.systolic, bp.diastolic) : null;

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: _BentoCard(
            title: tr('bento_exercise_title'),
            onTap: onOpenExercise,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(
                text: TextSpan(style: const TextStyle(color: ILifeTheme.navy), children: [
                  TextSpan(text: state.distanceKm.toStringAsFixed(2), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
                  TextSpan(text: ' ${tr('unit_km')}', style: const TextStyle(fontSize: 13)),
                ]),
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
              Text('${tr('burned_kcal')} ${state.caloriesKcal} kcal', style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(tr('in_health_plan'), style: const TextStyle(fontSize: 12, color: ILifeTheme.orange, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BentoCard(
            title: tr('bento_bp_title'),
            onTap: onMeasureBp,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                bp != null ? '${bp.systolic}/${bp.diastolic}' : tr('tap_to_measure'),
                style: TextStyle(fontSize: bp != null ? 24 : 18, fontWeight: FontWeight.w900, color: bpCat?.color ?? ILifeTheme.magenta),
              ),
              Text(bp != null ? 'mmHg · ${bpCat!.label}' : tr('cuff_f520'), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.favorite, size: 16, color: bpCat?.color ?? ILifeTheme.magenta),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bp?.pulse != null ? '${tr('pulse_label')} ${bp!.pulse} bpm' : tr('tap_start_now'),
                    style: const TextStyle(fontSize: 12, color: ILifeTheme.magenta, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: _BentoCard(
            title: tr('bento_ecg_title'),
            onTap: onMeasureEcg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                state.latestHeartRate != null ? '${state.latestHeartRate} bpm' : '-- bpm',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ILifeTheme.navy),
              ),
              const SizedBox(height: 4),
              Text(tr('ecg_30s_sub'), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
              const SizedBox(height: 8),
              Text(tr('start_ecg_now'), style: const TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BentoCard(
            title: tr('bento_spo2_title'),
            onTap: onMeasureSpo2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                state.latestSpo2 != null ? '${state.latestSpo2}%' : '--%',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ILifeTheme.navy),
              ),
              const SizedBox(height: 4),
              Text(
                state.latestTemperature != null
                    ? '${tr('temp_label')} ${state.latestTemperature!.toStringAsFixed(1)} °C'
                    : tr('auto_sync_f520'),
                style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
              ),
              const SizedBox(height: 8),
              Text(tr('normal_spo2'), style: const TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
      if (state.recentBp.isNotEmpty) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('recent_bp_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
              const SizedBox(height: 8),
              ...state.recentBp.take(5).map((r) {
                final c = BpCategory.of(r.systolic, r.diastolic);
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: CircleAvatar(backgroundColor: c.color, radius: 6),
                  title: Text('${r.systolic}/${r.diastolic} mmHg${r.pulse != null ? ' · ${tr('pulse_label')} ${r.pulse}' : ''}',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${formatShortDateTime(r.measuredAt)} · ${r.method == 'cuff' ? tr('method_cuff') : tr('method_optical')}'),
                  trailing: Text(c.label, style: TextStyle(color: c.color, fontWeight: FontWeight.w700)),
                );
              }),
            ]),
          ),
        ),
      ],
    ]);
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
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
            const SizedBox(height: 10),
            child,
          ]),
        ),
      ),
    );
  }
}
