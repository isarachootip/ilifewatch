import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_picker.dart';
import '../theme/ilife_theme.dart';

/// แท็บที่ 2: ออกกำลังกาย (ดีไซน์ตาม Huawei Health ในวิดีโอ)
class ExerciseTab extends StatefulWidget {
  const ExerciseTab({super.key, required this.onSync});

  final Future<void> Function() onSync;

  @override
  State<ExerciseTab> createState() => _ExerciseTabState();
}

class _ExerciseTabState extends State<ExerciseTab> {
  int _mode = 0;
  static const _modeKeys = ['mode_plan', 'mode_walk', 'mode_run_out', 'mode_run_in', 'mode_cycle'];
  static const _dayKeys = ['day_mon', 'day_tue', 'day_wed', 'day_thu', 'day_fri', 'day_sat', 'day_sun'];

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    const goal = 6000;
    final progress = (s.todaySteps / goal).clamp(0.0, 1.0);
    final todayWeekday = DateTime.now().weekday; // 1 = Mon .. 7 = Sun

    return Scaffold(
      appBar: AppBar(
        title: SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _modeKeys.length,
            separatorBuilder: (_, __) => const SizedBox(width: 18),
            itemBuilder: (_, i) {
              final active = i == _mode;
              return GestureDetector(
                onTap: () => setState(() => _mode = i),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr(_modeKeys[i]),
                      style: TextStyle(
                        fontSize: active ? 18 : 15,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                        color: active ? ILifeTheme.navy : ILifeTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (active)
                      Container(width: 20, height: 3, decoration: BoxDecoration(color: ILifeTheme.magenta, borderRadius: BorderRadius.circular(2))),
                  ],
                ),
              );
            },
          ),
        ),
        actions: const [
          LanguagePickerButton(),
          SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          tr('weekly_walk_plan'),
                          style: const TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy),
                        ),
                      ),
                      Text(
                        '${s.todaySteps} / $goal ${tr('unit_steps')}',
                        style: const TextStyle(color: ILifeTheme.magenta, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final isToday = (i + 1) == todayWeekday;
                      return Column(
                        children: [
                          Text(tr(_dayKeys[i]), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                          const SizedBox(height: 6),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isToday ? ILifeTheme.magenta : ILifeTheme.scaffoldBg,
                            child: Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isToday ? Colors.white : ILifeTheme.navy,
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  SizedBox(
                    width: 170,
                    height: 170,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: progress > 0 ? progress : 0.05,
                            strokeWidth: 14,
                            backgroundColor: ILifeTheme.magentaLight,
                            color: ILifeTheme.magenta,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              s.distanceKm.toStringAsFixed(2),
                              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: ILifeTheme.navy),
                            ),
                            Text(tr('km_today'), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _StatItem(label: tr('steps'), value: '${s.todaySteps}', unit: tr('unit_steps')),
                      _StatItem(label: tr('calories'), value: '${s.caloriesKcal}', unit: 'kcal'),
                      _StatItem(label: tr('latest_pulse'), value: '${s.latestHeartRate ?? "-"}', unit: 'bpm'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onSync,
                      icon: const Icon(Icons.sync),
                      label: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(tr('update_steps_btn')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.unit});
  final String label, value, unit;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Text(label, style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
      Text(unit, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
    ]);
  }
}
