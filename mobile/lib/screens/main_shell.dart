import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/sync_service.dart';
import '../theme/ilife_theme.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'devices_tab.dart';
import 'exercise_tab.dart';
import 'health_tab.dart';
import 'ilife_care_tab.dart';
import 'profile_tab.dart';

/// โครงสร้างหลัก 5 แท็บสไตล์ Huawei Health + ธีมสี iLife Care
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  final _watch = WatchService.instance;
  int _tab = 0;
  WatchConnection _conn = WatchConnection.disconnected;
  double? _syncProgress;
  StreamSubscription? _connSub, _progSub;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _conn = _watch.state;
    _connSub = _watch.connection.listen((c) {
      if (mounted) setState(() => _conn = c);
      if (c == WatchConnection.disconnected) _scheduleReconnect();
    });
    _progSub = SyncService.instance.progress.stream.listen((p) {
      if (mounted) setState(() => _syncProgress = p >= 1 ? null : p);
    });
    if (_conn != WatchConnection.ready && AppState.instance.pairedMac != null) {
      _reconnect();
    }
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _progSub?.cancel();
    super.dispose();
  }

  void _scheduleReconnect() {
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _conn != WatchConnection.ready) _reconnect();
    });
  }

  Future<void> _reconnect() async {
    final mac = AppState.instance.pairedMac;
    if (mac == null || _reconnecting) return;
    _reconnecting = true;
    try {
      final found = _watch.scanResults.firstWhere((w) => w.mac == mac).timeout(const Duration(seconds: 20));
      await _watch.startScan();
      await found;
      await _watch.connect(mac);
      await SyncService.instance.afterConnect();
    } catch (_) {
      await _watch.stopScan();
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> _sync() async {
    try {
      await SyncService.instance.syncAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ซิงค์ข้อมูลจากนาฬิกา F520Pro เรียบร้อย')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ซิงค์ไม่สำเร็จ: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final pages = [
          HealthTab(
            conn: _conn,
            syncProgress: _syncProgress,
            onSync: _sync,
            onReconnect: _reconnect,
            onSwitchTab: (i) => setState(() => _tab = i),
          ),
          ExerciseTab(onSync: _sync),
          const ILifeCareTab(),
          DevicesTab(conn: _conn, onSync: _sync, onReconnect: _reconnect),
          ProfileTab(onSync: _sync),
        ];

        return Scaffold(
          body: IndexedStack(index: _tab, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            backgroundColor: Colors.white,
            indicatorColor: ILifeTheme.magentaLight,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite, color: ILifeTheme.magenta),
                label: 'สุขภาพ',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_run_outlined),
                selectedIcon: Icon(Icons.directions_run, color: ILifeTheme.magenta),
                label: 'ออกกำลังกาย',
              ),
              NavigationDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop, color: ILifeTheme.magenta),
                label: 'iLife Care',
              ),
              NavigationDestination(
                icon: Icon(Icons.watch_outlined),
                selectedIcon: Icon(Icons.watch, color: ILifeTheme.magenta),
                label: 'อุปกรณ์',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person, color: ILifeTheme.magenta),
                label: 'ฉัน',
              ),
            ],
          ),
        );
      },
    );
  }
}
