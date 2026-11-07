import 'package:flutter/material.dart';

import '../../l10n/app_language.dart';
import '../../theme/ilife_theme.dart';

/// ตารางแสดงผล 6 ค่าสุขภาพของหน้าตรวจสุขภาพด่วน 60 วินาที
/// รองรับการรีเซ็ตเป็น `--` เมื่อเริ่มวัด และการไฮไลต์ช่องที่เซนเซอร์กำลังวัดอยู่ตาม `activeStage`
class MiniCheckupGrid extends StatelessWidget {
  final AppLanguage language;
  final bool busy;
  final int activeStage;
  final int? systolic;
  final int? diastolic;
  final int? heartRate;
  final int? spo2;
  final double? temperature;
  final int? stress;
  final int? hrv;

  const MiniCheckupGrid({
    super.key,
    required this.language,
    required this.busy,
    required this.activeStage,
    required this.systolic,
    required this.diastolic,
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    required this.stress,
    required this.hrv,
  });

  static String measuringBadgeFor(AppLanguage l) => switch (l) {
        AppLanguage.th => 'กำลังวัด...',
        AppLanguage.en => 'Measuring...',
        AppLanguage.zh => '测量中...',
        AppLanguage.ar => 'جاري القياس...',
        AppLanguage.de => 'Messung...',
        AppLanguage.jawi => 'سدڠ مغوكور...',
        AppLanguage.ru => 'Измерение...',
        AppLanguage.he => 'מודד...',
      };

  @override
  Widget build(BuildContext context) {
    final hasBp = systolic != null && diastolic != null && systolic! > 0 && diastolic! > 0;
    final hasHr = heartRate != null && heartRate! > 0;
    final hasSpo2 = spo2 != null && spo2! > 0;
    final hasTemp = temperature != null && temperature! > 30;
    final hasStress = stress != null && stress! > 0;
    final hasHrv = hrv != null && hrv! > 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.50,
      children: [
        _buildTile(
          label: 'BP (mmHg)',
          value: hasBp ? '$systolic/$diastolic' : '--/--',
          icon: Icons.speed,
          color: ILifeTheme.magenta,
          measuring: busy && activeStage == 3 && !hasBp,
        ),
        _buildTile(
          label: 'Heart Rate',
          value: hasHr ? '$heartRate bpm' : '-- bpm',
          icon: Icons.favorite,
          color: const Color(0xFFE53935),
          measuring: busy && activeStage == 1 && !hasHr,
        ),
        _buildTile(
          label: 'SpO2',
          value: hasSpo2 ? '$spo2%' : '--%',
          icon: Icons.air,
          color: ILifeTheme.teal,
          measuring: busy && activeStage == 2 && !hasSpo2,
        ),
        _buildTile(
          label: 'Body Temp',
          value: hasTemp ? '${temperature!.toStringAsFixed(1)} °C' : '--.- °C',
          icon: Icons.thermostat,
          color: const Color(0xFFFB8C00),
          measuring: busy && activeStage == 4 && !hasTemp,
        ),
        _buildTile(
          label: 'Stress',
          value: hasStress ? '$stress' : '--',
          icon: Icons.psychology_alt,
          color: ILifeTheme.navy,
          measuring: busy && activeStage == 4 && !hasStress,
        ),
        _buildTile(
          label: 'HRV',
          value: hasHrv ? '$hrv ms' : '-- ms',
          icon: Icons.monitor_heart_outlined,
          color: const Color(0xFF8E24AA),
          measuring: busy && activeStage == 4 && !hasHrv,
        ),
      ],
    );
  }

  Widget _buildTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool measuring,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: measuring ? color.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: measuring ? color : const Color(0xFFE5E7EB),
          width: measuring ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (measuring)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    measuringBadgeFor(language),
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
                  ),
                ),
            ],
          ),
          Text(
            value,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color),
          ),
        ],
      ),
    );
  }
}
