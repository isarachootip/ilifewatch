import 'package:flutter/material.dart';

import '../watch/watch_models.dart';
import 'bp_category.dart';

String formatShortDateTime(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)} ${two(l.hour)}:${two(l.minute)}';
}

class ConnectionBar extends StatelessWidget {
  const ConnectionBar({
    super.key,
    required this.conn,
    required this.battery,
    required this.org,
    required this.onRetry,
  });

  final WatchConnection conn;
  final Map<String, dynamic>? battery;
  final String? org;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (conn) {
      WatchConnection.ready => ('เชื่อมต่อนาฬิกาแล้ว', const Color(0xFF188038)),
      WatchConnection.connecting || WatchConnection.connected => ('กำลังเชื่อมต่อ...', const Color(0xFFC9A100)),
      _ => ('ไม่ได้เชื่อมต่อนาฬิกา', const Color(0xFF5F6368)),
    };
    String? bat;
    if (battery != null) {
      bat = battery!['isPercent'] == true ? '${battery!['percent']}%' : '${battery!['level']}/4';
    }
    return Row(children: [
      Icon(Icons.circle, size: 12, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(org?.isNotEmpty == true ? '$text · $org' : text)),
      if (bat != null) ...[const Icon(Icons.battery_std, size: 18), Text(bat)],
      if (conn == WatchConnection.disconnected || conn == WatchConnection.failed)
        TextButton(onPressed: onRetry, child: const Text('ลองใหม่')),
    ]);
  }
}

class BpCard extends StatelessWidget {
  const BpCard({super.key, required this.bp});
  final BpReading? bp;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (bp == null) {
      return const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('ยังไม่มีข้อมูลความดัน')));
    }
    final c = BpCategory.of(bp!.systolic, bp!.diastolic);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ความดันล่าสุด', style: t.titleSmall),
          const SizedBox(height: 4),
          Text('${bp!.systolic}/${bp!.diastolic}', style: t.displaySmall?.copyWith(fontWeight: FontWeight.bold)),
          Text('mmHg${bp!.pulse != null ? ' · ชีพจร ${bp!.pulse}' : ''}'),
          const SizedBox(height: 8),
          Chip(label: Text(c.label), backgroundColor: c.color.withAlpha(38)),
          Text(formatShortDateTime(bp!.measuredAt), style: t.bodySmall),
        ]),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String? value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(icon, size: 18), const SizedBox(width: 6), Text(label)]),
          const SizedBox(height: 6),
          Text(value ?? '-', style: t.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(unit, style: t.bodySmall),
        ]),
      ),
    );
  }
}
