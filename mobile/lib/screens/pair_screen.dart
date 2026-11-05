import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';
import '../l10n/app_strings.dart';
import '../services/sync_service.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'widgets/pair_troubleshoot_card.dart';

/// ค้นหาและจับคู่นาฬิกา F520Pro (คัดกรองเฉพาะนาฬิกา + เชื่อมต่ออัตโนมัติเมื่อพบเรือนเดียวในระยะใกล้)
class PairScreen extends StatefulWidget {
  const PairScreen({super.key});

  @override
  State<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends State<PairScreen> {
  final _found = <String, ScannedWatch>{};
  StreamSubscription<ScannedWatch>? _sub;
  StreamSubscription<WatchConnection>? _connSub;
  Timer? _autoTimer;
  String? _connecting;
  WatchConnection _stage = WatchConnection.disconnected;
  String? _error;
  bool _autoAttempted = false;

  @override
  void initState() {
    super.initState();
    _connSub = WatchService.instance.connection.listen((s) {
      if (mounted) setState(() => _stage = s);
    });
    _start();
  }

  Future<bool> _askPermissions() async {
    if (!Platform.isAndroid) return true;
    final req = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.bluetoothAdvertise,
      Permission.locationWhenInUse,
    ].request();
    final btOk = (req[Permission.bluetoothScan]?.isGranted ?? false) &&
        (req[Permission.bluetoothConnect]?.isGranted ?? false);
    final locOk = req[Permission.locationWhenInUse]?.isGranted ?? false;
    return btOk || locOk;
  }

  Future<void> _start() async {
    setState(() => _error = null);
    if (!await _askPermissions()) {
      setState(() => _error = tr('perm_bt_error'));
      return;
    }
    _sub?.cancel();
    _sub = WatchService.instance.scanResults.listen(_onWatchDiscovered);
    await WatchService.instance.startScan();
  }

  void _onWatchDiscovered(ScannedWatch w) {
    final savedMac = AppState.instance.pairedMac;
    if (!w.isWatchCandidate(pairedMac: savedMac)) return;
    setState(() => _found[w.mac] = w);
    if (_connecting != null || _autoAttempted) return;

    // กรณีเจอเรือนเดิมที่เคยจับคู่ไว้ หรือเจอ F520Pro สัญญาณแรงมากใกล้ตัว ให้ต่ออัตโนมัติทันที
    if (savedMac != null && w.mac.toUpperCase() == savedMac.toUpperCase()) {
      _autoAttempted = true;
      _connect(w);
      return;
    }
    _autoTimer ??= Timer(const Duration(milliseconds: 1500), () {
      if (!mounted || _connecting != null || _autoAttempted) return;
      final candidates = _found.values.where((d) => d.isPrimaryF520).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
      if (candidates.length == 1 || (candidates.isNotEmpty && candidates.first.rssi >= -65)) {
        _autoAttempted = true;
        _connect(candidates.first);
      }
    });
  }

  Future<void> _connect(ScannedWatch w) async {
    _autoTimer?.cancel();
    final name = w.name.isEmpty ? 'F520Pro' : w.name;
    setState(() {
      _connecting = w.mac;
      _stage = WatchConnection.connecting;
      _error = null;
    });
    try {
      await WatchService.instance.connect(w.mac, name: name);
      await AppState.instance.setPaired(w.mac, name);
      unawaited(SyncService.instance.afterConnect());
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = tr('connect_fail_error'));
    } finally {
      if (mounted) setState(() => _connecting = null);
    }
  }

  String _stageText() => switch (_stage) {
        WatchConnection.connecting => 'ขั้นตอนที่ 1/3: กำลังเชื่อมสัญญาณบลูทูธ GATT กับนาฬิกา...',
        WatchConnection.connected => 'ขั้นตอนที่ 2/3: เชื่อมต่อสำเร็จ กำลังยืนยันรหัส 0000...',
        WatchConnection.ready => 'ขั้นตอนที่ 3/3: พร้อมใช้งาน กำลังซิงค์ข้อมูลสุขภาพ...',
        _ => 'กำลังเตรียมการเชื่อมต่อ...',
      };

  @override
  void dispose() {
    _autoTimer?.cancel();
    _sub?.cancel();
    _connSub?.cancel();
    WatchService.instance.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final list = _found.values.toList()..sort((a, b) => b.rssi.compareTo(a.rssi));
    final savedMac = AppState.instance.pairedMac;
    final savedName = AppState.instance.pairedName ?? 'F520Pro';
    return Scaffold(
      appBar: AppBar(title: Text(tr('pair_screen_title')), actions: [
        IconButton(onPressed: () => showPairTroubleshootDialog(context), icon: const Icon(Icons.help_outline)),
        IconButton(onPressed: _start, icon: const Icon(Icons.refresh)),
      ]),
      body: Column(
        children: [
          Padding(padding: const EdgeInsets.fromLTRB(16, 12, 16, 6), child: Text(tr('pair_guide_text'))),
          const PairTroubleshootBanner(),
          if (_connecting != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                tileColor: const Color(0xFFE0F2F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
                title: Text(_stageText(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          if (savedMac != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _connecting == null
                      ? () => _connect(ScannedWatch(name: savedName, mac: savedMac, rssi: -45, isVp: true))
                      : null,
                  icon: const Icon(Icons.bolt),
                  label: Text('เชื่อมต่อตรงกับเรือนเดิมทันที ($savedName · $savedMac)'),
                ),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          Expanded(
            child: list.isEmpty
                ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('กำลังสแกนหานาฬิกา F520Pro ใกล้ตัวคุณ...'),
                  ]))
                : ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final w = list[i];
                      return ListTile(
                        leading: const Icon(Icons.watch),
                        title: Text(w.name.isEmpty ? 'F520Pro' : w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
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
