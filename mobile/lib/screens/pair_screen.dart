import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/sync_service.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';

/// ค้นหาและจับคู่นาฬิกา
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _found = <String, ScannedWatch>{};
  StreamSubscription<ScannedWatch>? _sub;
  String? _connecting;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<bool> _askPermissions() async {
    if (!Platform.isAndroid) return true;
    final bt = await [Permission.bluetoothScan, Permission.bluetoothConnect].request();
    if (bt.values.every((s) => s.isGranted || s.isLimited)) return true;
    final loc = await Permission.locationWhenInUse.request();
    return loc.isGranted || loc.isLimited;
  }

  Future<void> _start() async {
    if (!await _askPermissions()) {
      setState(() => _error = tr('perm_bt_error'));
      return;
    }
    _sub?.cancel();
    _sub = WatchService.instance.scanResults.listen((w) {
      setState(() => _found[w.mac] = w);
    });
    await WatchService.instance.startScan();
  }

  Future<void> _connect(ScannedWatch w) async {
    setState(() {
      _connecting = w.mac;
      _error = null;
    });
    try {
      await WatchService.instance.connect(w.mac);
      await AppState.instance.setPaired(w.mac, w.name);
      unawaited(SyncService.instance.afterConnect());
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = tr('connect_fail_error'));
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    WatchService.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    return Scaffold(
      appBar: AppBar(title: Text(tr('pair_screen_title')), actions: [
        IconButton(onPressed: _start, icon: const Icon(Icons.refresh)),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tr('pair_guide_text')),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      return ListTile(
                        leading: const Icon(Icons.watch),
                        title: Text(w.name.isEmpty ? tr('unnamed_device') : w.name),
                        subtitle: Text('${w.mac}  ${tr('signal_dbm')} ${w.rssi} dBm'),
                        trailing: _connecting == w.mac
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.chevron_right),
                        onTap: _connecting == null ? () => _connect(w) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
