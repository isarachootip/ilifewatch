import 'package:flutter/material.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../l10n/language_picker.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_models.dart';
import 'bp_screen.dart';
import 'ecg_screen.dart';
import 'home_widgets.dart';
import 'pair_screen.dart';
import 'spo2_temp_screen.dart';
import 'widgets/health_bento_grid.dart';
import 'widgets/health_clover_card.dart';

/// แท็บที่ 1: สุขภาพ (ดีไซน์ Huawei Health + ธีมสี iLife Care)
class HealthTab extends StatelessWidget {
  const HealthTab({
    super.key,
    required this.conn,
    required this.syncProgress,
    required this.onSync,
    required this.onReconnect,
    required this.onSwitchTab,
  });

  final WatchConnection conn;
  final double? syncProgress;
  final Future<void> Function() onSync;
  final Future<void> Function() onReconnect;
  final void Function(int index) onSwitchTab;

  void _openBp(BuildContext context) {
    if (conn != WatchConnection.ready) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const BpScreen()));
  }

  void _openEcg(BuildContext context) {
    if (conn != WatchConnection.ready) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const EcgScreen()));
  }

  void _openSpo2(BuildContext context) {
    if (conn != WatchConnection.ready) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Spo2TempScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.instance;
    final ready = conn == WatchConnection.ready;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('tab_health')),
        actions: [
          const Center(child: ILifeLogo(fontSize: 19, showSubtitle: false)),
          const SizedBox(width: 6),
          const LanguagePickerButton(),
          IconButton(
            onPressed: () => onSwitchTab(3),
            tooltip: tr('connect_watch_tooltip'),
            icon: Icon(
              Icons.watch,
              color: ready ? ILifeTheme.teal : ILifeTheme.magenta,
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: ready ? onSync : onReconnect,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: ConnectionBar(
                  conn: conn,
                  battery: s.battery,
                  org: s.orgName,
                  onRetry: () {
                    if (s.pairedMac == null) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen()));
                    } else {
                      onReconnect();
                    }
                  },
                ),
              ),
            ),
            if (syncProgress != null) ...[
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(value: syncProgress, color: ILifeTheme.magenta),
              ),
              const SizedBox(height: 4),
              Text(
                '${tr('syncing_pct')} ${(syncProgress! * 100).round()}%',
                style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
              ),
            ],
            const SizedBox(height: 12),
            HealthCloverCard(
              state: s,
              onMeasureBp: () => _openBp(context),
              onMeasureEcg: () => _openEcg(context),
              onSync: ready ? onSync : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PairScreen())),
              onOpenCare: () => onSwitchTab(2),
              onOpenDevices: () => onSwitchTab(3),
            ),
            const SizedBox(height: 12),
            HealthBentoGrid(
              state: s,
              onMeasureBp: () => _openBp(context),
              onMeasureEcg: () => _openEcg(context),
              onMeasureSpo2: () => _openSpo2(context),
              onOpenExercise: () => onSwitchTab(1),
            ),
            if (s.alerts.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                tr('care_alerts_title'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy),
              ),
              const SizedBox(height: 8),
              ...s.alerts.take(5).map((a) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      color: a['level'] == 'critical' ? const Color(0xFFFDECEA) : const Color(0xFFFFF4E5),
                      child: ListTile(
                        leading: const Icon(Icons.warning_amber, color: ILifeTheme.magenta),
                        title: Text(translateAlertMessage(a['message']?.toString() ?? '')),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 20),
            Text(
              tr('medical_disclaimer'),
              style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
