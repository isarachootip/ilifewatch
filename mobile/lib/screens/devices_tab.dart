import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_picker.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'bp_screen.dart';
import 'ecg_screen.dart';
import 'pair_screen.dart';

/// แท็บที่ 4: อุปกรณ์ (ดีไซน์ตามหน้า "อุปกรณ์" ของ Huawei Health ในวิดีโอ)
class DevicesTab extends StatelessWidget {
  const DevicesTab({super.key, required this.conn, required this.onSync, required this.onReconnect});

  final WatchConnection conn;
  final Future<void> Function() onSync;
  final Future<void> Function() onReconnect;

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final ready = conn == WatchConnection.ready;
    final bat = s.battery;
    final batText = bat == null
        ? (ready ? tr('ready_status') : tr('tap_to_connect'))
        : (bat['isPercent'] == true ? '${bat['percent']}%' : '${tr('bat_level')} ${bat['level']}/4');

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('tab_devices')),
        actions: [
          const LanguagePickerButton(),
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
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('devices_banner_title'), style: const TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                  const SizedBox(height: 4),
                  Text(tr('devices_banner_sub'), style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary)),
                ]),
              ),
              const Icon(Icons.watch, size: 42, color: ILifeTheme.magenta),
            ]),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                Row(children: [
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
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        s.pairedName?.isNotEmpty == true ? s.pairedName! : 'iLife Watch F520Pro',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: ILifeTheme.navy),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Icon(Icons.battery_charging_full, size: 18, color: ready ? const Color(0xFF2E7D32) : ILifeTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(batText, style: TextStyle(fontWeight: FontWeight.w700, color: ready ? const Color(0xFF2E7D32) : ILifeTheme.textSecondary)),
                      ]),
                      if (s.pairedMac != null)
                        Text('MAC: ${s.pairedMac}', style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
                    ]),
                  ),
                ]),
                const Divider(height: 28),
                Wrap(alignment: WrapAlignment.spaceEvenly, spacing: 12, children: [
                  TextButton.icon(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
                    icon: const Icon(Icons.bluetooth_searching, color: ILifeTheme.magenta),
                    label: Text(
                      s.pairedMac == null ? tr('add_f520') : tr('change_pair_watch'),
                      style: const TextStyle(color: ILifeTheme.magenta, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (s.pairedMac != null && !ready)
                    TextButton.icon(
                      onPressed: onReconnect,
                      icon: const Icon(Icons.refresh, color: ILifeTheme.teal),
                      label: Text(tr('reconnect'), style: const TextStyle(color: ILifeTheme.teal, fontWeight: FontWeight.w700)),
                    ),
                ]),
              ]),
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
                title: tr('act_bp_title'),
                subtitle: tr('act_bp_sub'),
                icon: Icons.monitor_heart,
                color: ILifeTheme.magenta,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ready ? const BpScreen() : const PairScreen())),
              ),
              _DeviceActionTile(
                title: tr('act_ecg_title'),
                subtitle: tr('act_ecg_sub'),
                icon: Icons.show_chart,
                color: ILifeTheme.teal,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ready ? const EcgScreen() : const PairScreen())),
              ),
              _DeviceActionTile(
                title: tr('act_sync_title'),
                subtitle: tr('act_sync_sub'),
                icon: Icons.cloud_sync,
                color: ILifeTheme.orange,
                onTap: ready ? onSync : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
              ),
              _DeviceActionTile(
                title: tr('act_unpair_title'),
                subtitle: tr('act_unpair_sub'),
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
  const _DeviceActionTile({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
  final String title, subtitle;
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
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: ILifeTheme.navy), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
              ]),
            ),
            Icon(icon, color: color, size: 28),
          ]),
        ),
      ),
    );
  }
}
