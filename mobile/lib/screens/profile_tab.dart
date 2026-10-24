import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_picker.dart';
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
        title: Text(tr('tab_profile')),
        actions: [
          const LanguagePickerButton(),
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
              leading: const CircleAvatar(
                radius: 28,
                backgroundColor: ILifeTheme.magentaLight,
                child: Icon(Icons.person, size: 32, color: ILifeTheme.magenta),
              ),
              title: Text(
                s.isLoggedIn ? (s.patientName ?? tr('user_default_name')) : tr('not_linked_org'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ILifeTheme.navy),
              ),
              subtitle: Text(
                s.isLoggedIn
                    ? '${s.orgName ?? tr('org_default_name')} · ${tr('auto_sync')}'
                    : tr('tap_to_enroll'),
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
                      Text('${tr('server_label')}: ${s.server}', style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
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
                  title: tr('care_org'),
                  subtitle: s.orgName ?? tr('link_with_code'),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickProfileCard(
                  icon: Icons.favorite,
                  color: ILifeTheme.magenta,
                  title: tr('latest_bp'),
                  subtitle: s.latestBp != null ? '${s.latestBp!.systolic}/${s.latestBp!.diastolic}' : tr('no_history'),
                  onTap: onSync,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _QuickProfileCard(
                  icon: Icons.summarize,
                  color: ILifeTheme.purple,
                  title: tr('last_sync'),
                  subtitle: s.lastSync != null ? formatShortDateTime(s.lastSync!) : tr('tap_to_sync'),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  child: Text(tr('settings_section_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                ),
                ListTile(
                  leading: const Icon(Icons.language, color: ILifeTheme.magenta),
                  title: Text(tr('language_setting_title')),
                  subtitle: Text('${s.language.nativeName} (${s.language.englishName})'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showLanguagePickerSheet(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.badge_outlined, color: ILifeTheme.teal),
                  title: Text(tr('enroll_menu_title')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen())),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bar_chart, color: ILifeTheme.magenta),
                  title: Text(tr('personal_info_title')),
                  subtitle: Text(
                    s.profile != null
                        ? '${tr('height_cm')} ${s.profile!.heightCm} cm · ${tr('weight_kg')} ${s.profile!.weightKg} kg · ${tr('birth_year')} ${s.profile!.birthYear}'
                        : tr('personal_info_default'),
                  ),
                ),
                if (s.isLoggedIn) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: Text(tr('logout_org'), style: const TextStyle(color: Colors.redAccent)),
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
  const _QuickProfileCard({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withAlpha(28), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 10),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: ILifeTheme.navy)),
            const SizedBox(height: 2),
            Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
          ]),
        ),
      ),
    );
  }
}
