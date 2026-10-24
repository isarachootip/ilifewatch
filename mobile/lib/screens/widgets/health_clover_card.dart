import 'package:flutter/material.dart';

import '../../app_state.dart';
import '../../l10n/app_strings.dart';
import '../../theme/ilife_theme.dart';

/// การ์ดวงแหวน 3 ใบสไตล์ Huawei Health + แถบเมนูด่วน 5 รายการ
class HealthCloverCard extends StatelessWidget {
  const HealthCloverCard({
    super.key,
    required this.state,
    required this.onMeasureBp,
    required this.onMeasureEcg,
    required this.onSync,
    required this.onOpenCare,
    required this.onOpenDevices,
  });

  final AppState state;
  final VoidCallback onMeasureBp, onMeasureEcg, onSync, onOpenCare, onOpenDevices;

  @override
  Widget build(BuildContext context) {
    final bpText = state.latestBp != null
        ? '${state.latestBp!.systolic}/${state.latestBp!.diastolic}'
        : (state.latestHeartRate != null ? '${state.latestHeartRate}' : '--');
    final bpSub = state.latestBp != null ? tr('mmhg_latest') : tr('pulse_bpm');
    final doneCount = (state.latestBp != null ? 1 : 0) + (state.todaySteps > 0 ? 1 : 0) + (state.latestSleepMinutes > 0 ? 1 : 0);

    return Column(children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
          child: Column(children: [
            SizedBox(
              height: 118,
              width: 140,
              child: Stack(alignment: Alignment.center, children: [
                Positioned(top: 0, child: _PetalCircle(color: ILifeTheme.orange, icon: Icons.directions_run, active: state.todaySteps > 0)),
                Positioned(bottom: 4, left: 10, child: _PetalCircle(color: ILifeTheme.purple, icon: Icons.nightlight_round, active: state.latestSleepMinutes > 0)),
                Positioned(
                  bottom: 4,
                  right: 10,
                  child: _PetalCircle(color: ILifeTheme.teal, icon: Icons.favorite, active: state.latestBp != null || state.latestHeartRate != null),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _MetricColumn(
                  dotColor: ILifeTheme.purple,
                  title: tr('sleep'),
                  value: state.latestSleepMinutes > 0 ? state.sleepFormatted : tr('add_record'),
                  subtitle: state.latestSleepMinutes > 0 ? tr('latest_sleep') : tr('sync_from_watch'),
                  isValueBold: state.latestSleepMinutes > 0,
                ),
              ),
              Expanded(
                child: _MetricColumn(
                  dotColor: ILifeTheme.orange,
                  title: tr('steps'),
                  value: '${state.todaySteps}',
                  subtitle: tr('steps_today'),
                  isValueBold: true,
                ),
              ),
              Expanded(
                child: _MetricColumn(dotColor: ILifeTheme.teal, title: tr('bp_pulse'), value: bpText, subtitle: bpSub, isValueBold: true),
              ),
            ]),
            const SizedBox(height: 14),
            InkWell(
              onTap: onMeasureBp,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                decoration: BoxDecoration(color: ILifeTheme.scaffoldBg, borderRadius: BorderRadius.circular(24)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.assignment_turned_in, size: 18, color: ILifeTheme.teal),
                  const SizedBox(width: 6),
                  Text('${tr('daily_tasks_done')} $doneCount/3', style: const TextStyle(fontWeight: FontWeight.w600, color: ILifeTheme.navy)),
                ]),
              ),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _QuickIcon(icon: Icons.monitor_heart, color: ILifeTheme.magenta, label: tr('quick_bp'), onTap: onMeasureBp),
            _QuickIcon(icon: Icons.monitor_heart_outlined, color: ILifeTheme.teal, label: tr('quick_ecg'), onTap: onMeasureEcg),
            _QuickIcon(icon: Icons.sync, color: ILifeTheme.orange, label: tr('quick_sync'), onTap: onSync),
            _QuickIcon(icon: Icons.watch, color: ILifeTheme.purple, label: tr('quick_watch'), onTap: onOpenDevices),
            _QuickIcon(icon: Icons.water_drop, color: const Color(0xFF0288D1), label: tr('quick_care'), onTap: onOpenCare),
          ]),
        ),
      ),
    ]);
  }
}

class _PetalCircle extends StatelessWidget {
  const _PetalCircle({required this.color, required this.icon, required this.active});
  final Color color;
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(active ? 210 : 75),
        boxShadow: [BoxShadow(color: color.withAlpha(40), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({required this.dotColor, required this.title, required this.value, required this.subtitle, required this.isValueBold});
  final Color dotColor;
  final String title, value, subtitle;
  final bool isValueBold;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Flexible(child: Text(title, style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary), overflow: TextOverflow.ellipsis)),
      ]),
      const SizedBox(height: 4),
      Text(value, style: TextStyle(fontSize: isValueBold ? 20 : 13, fontWeight: isValueBold ? FontWeight.w800 : FontWeight.w600, color: ILifeTheme.navy)),
      const SizedBox(height: 2),
      Text(subtitle, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary), overflow: TextOverflow.ellipsis),
    ]);
  }
}

class _QuickIcon extends StatelessWidget {
  const _QuickIcon({required this.icon, required this.color, required this.label, required this.onTap});
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Column(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, height: 1.2, color: ILifeTheme.navy)),
        ]),
      ),
    );
  }
}
