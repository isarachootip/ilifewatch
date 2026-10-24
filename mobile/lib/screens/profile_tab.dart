import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_service.dart';
import 'home_widgets.dart';
import 'setup_screen.dart';

/// แท็บที่ 5: ฉัน (ดีไซน์ตามหน้า "ฉัน" ของ Huawei Health ในวิดีโอ)
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key, required this.onSync});

  final Future<void> Function() onSync;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ฉัน'),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
            icon: const Icon(Icons.settings_outlined, color: ILifeTheme.navy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              leading: CircleAvatar(
                radius: 28,
                backgroundColor: ILifeTheme.magentaLight,
                child: const Icon(Icons.person, size: 32, color: ILifeTheme.magenta),
              ),
              title: Text(
                s.isLoggedIn ? (s.patientName ?? 'ผู้ใช้งาน iLife Watch') : 'ยังไม่ได้ผูกบัญชีหน่วยงาน',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ILifeTheme.navy),
              ),
              subtitle: Text(
                s.isLoggedIn
                    ? '${s.orgName ?? "ศูนย์ดูแลสุขภาพ"} · ซิงค์อัตโนมัติ'
                    : 'แตะเพื่อกรอกรหัสลงทะเบียน (เช่น CARE0001)',
                style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified, color: Color(0xFFF57F17)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('iLife Care+ Health Cloud', style: TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                      Text('เซิร์ฟเวอร์: ${s.server}', style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: ILifeTheme.navy),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _QuickProfileCard(
                  icon: Icons.local_hospital,
                  color: ILifeTheme.teal,
                  title: 'หน่วยงานดูแล',
                  subtitle: s.orgName ?? 'ผูกด้วย CARE0001',
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickProfileCard(
                  icon: Icons.favorite,
                  color: ILifeTheme.magenta,
                  title: 'ความดันล่าสุด',
                  subtitle: s.latestBp != null ? '${s.latestBp!.systolic}/${s.latestBp!.diastolic}' : 'ยังไม่มีประวัติ',
                  onTap: onSync,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickProfileCard(
                  icon: Icons.summarize,
                  color: ILifeTheme.purple,
                  title: 'ซิงค์ล่าสุด',
                  subtitle: s.lastSync != null ? formatShortDateTime(s.lastSync!) : 'แตะเพื่อซิงค์',
                  onTap: onSync,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text('ข้อมูลสุขภาพและการตั้งค่า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                ),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: ILifeTheme.teal),
                  title: const Text('ผูกบัญชี / เปลี่ยนรหัสลงทะเบียน (CARE0001)'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bar_chart, color: ILifeTheme.magenta),
                  title: const Text('ข้อมูลส่วนตัวสำหรับคำนวณความดัน'),
                  subtitle: Text(
                    s.profile != null
                        ? 'ส่วนสูง ${s.profile!.heightCm} ซม. · น้ำหนัก ${s.profile!.weightKg} กก. · พ.ศ./ค.ศ. ${s.profile!.birthYear}'
                        : 'ค่ามาตรฐาน (160 ซม. / 60 กก.)',
                  ),
                ),
                if (s.isLoggedIn) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('ออกจากระบบบัญชีหน่วยงาน', style: TextStyle(color: Colors.redAccent)),
                    onTap: () async {
                      await WatchService.instance.disconnect();
                      await AppState.instance.logout();
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickProfileCard extends StatelessWidget {
  const _QuickProfileCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ILifeTheme.navy)),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}
