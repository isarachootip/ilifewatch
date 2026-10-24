import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'bp_screen.dart';
import 'ecg_screen.dart';
import 'pair_screen.dart';

/// แท็บที่ 4: อุปกรณ์ (ดีไซน์ตามหน้า "อุปกรณ์" ของ Huawei Health ในวิดีโอ)
class DevicesTab extends StatelessWidget {
  const DevicesTab({
    super.key,
    required this.conn,
    required this.onSync,
    required this.onReconnect,
  });

  final WatchConnection conn;
  final Future<void> Function() onSync;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final ready = conn == WatchConnection.ready;
    final bat = s.battery;
    final batText = bat == null
        ? (ready ? 'พร้อมใช้งาน' : 'แตะเพื่อเชื่อมต่อ')
        : (bat['isPercent'] == true ? '${bat['percent']}%' : 'ระดับ ${bat['level']}/4');

    return Scaffold(
      appBar: AppBar(
        title: const Text('อุปกรณ์'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
            icon: const Icon(Icons.add_circle_outline, color: ILifeTheme.navy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF3E0), Color(0xFFFCE4EC)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ดูแลความดันและหัวใจตลอด 24 ชม.', style: TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                      SizedBox(height: 4),
                      Text('สวมใส่ F520Pro เพื่อวัดความดันถุงลมและคลื่นไฟฟ้าหัวใจ ECG', style: TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                    ],
                  ),
                ),
                Icon(Icons.watch, size: 42, color: ILifeTheme.magenta),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: ready ? ILifeTheme.tealLight : ILifeTheme.scaffoldBg,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(Icons.watch_rounded, size: 42, color: ready ? ILifeTheme.teal : ILifeTheme.navy),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.pairedName?.isNotEmpty == true ? s.pairedName! : 'iLife Watch F520Pro',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ILifeTheme.navy),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.battery_charging_full, size: 18, color: ready ? const Color(0xFF2E7D32) : ILifeTheme.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  batText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ready ? const Color(0xFF2E7D32) : ILifeTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (s.pairedMac != null)
                              Text('MAC: ${s.pairedMac}', style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
                        icon: const Icon(Icons.bluetooth_searching, color: ILifeTheme.magenta),
                        label: Text(
                          s.pairedMac == null ? 'เพิ่มอุปกรณ์ F520Pro' : 'เปลี่ยน / จับคู่นาฬิกา',
                          style: const TextStyle(color: ILifeTheme.magenta, fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (s.pairedMac != null && !ready)
                        TextButton.icon(
                          onPressed: onReconnect,
                          icon: const Icon(Icons.refresh, color: ILifeTheme.teal),
                          label: const Text('เชื่อมต่อใหม่', style: TextStyle(color: ILifeTheme.teal, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: [
              _DeviceActionTile(
                title: 'วัดความดันปั๊มลม',
                subtitle: 'ถุงลมในสายนาฬิกา',
                icon: Icons.monitor_heart,
                color: ILifeTheme.magenta,
                onTap: () {
                  if (!ready) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const BpScreen()));
                  }
                },
              ),
              _DeviceActionTile(
                title: 'วัดคลื่นหัวใจ ECG',
                subtitle: 'แสดงกราฟสด 30 วินาที',
                icon: Icons.show_chart,
                color: ILifeTheme.teal,
                onTap: () {
                  if (!ready) {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const EcgScreen()));
                  }
                },
              ),
              _DeviceActionTile(
                title: 'ซิงค์ข้อมูล 3 วัน',
                subtitle: 'ความดัน ชีพจร การนอน',
                icon: Icons.cloud_sync,
                color: ILifeTheme.orange,
                onTap: ready
                    ? onSync
                    : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
              ),
              _DeviceActionTile(
                title: 'ยกเลิกการจับคู่',
                subtitle: 'ตัดการเชื่อมต่อปัจจุบัน',
                icon: Icons.link_off,
                color: ILifeTheme.purple,
                onTap: () async {
                  await WatchService.instance.disconnect();
                  await AppState.instance.unpair();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DeviceActionTile extends StatelessWidget {
  const _DeviceActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ILifeTheme.navy)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
                  ],
                ),
              ),
              Icon(icon, color: color, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
