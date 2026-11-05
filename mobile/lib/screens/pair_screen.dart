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
    final savedMac = AppState.instance.pairedMac;
    final savedName = AppState.instance.pairedName ?? 'F520Pro';
    return Scaffold(
      appBar: AppBar(title: Text(tr('pair_screen_title')), actions: [
        IconButton(onPressed: () => _showTroubleshootDialog(context), icon: const Icon(Icons.help_outline)),
        IconButton(onPressed: _start, icon: const Icon(Icons.refresh)),
      ]),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
            child: Text(tr('pair_guide_text')),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _showTroubleshootDialog(context),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: const Row(children: [
                  Icon(Icons.tips_and_updates, color: Color(0xFFF57F17)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'เชื่อมต่อไม่ติด / ค้นหาไม่เจอ? แตะดู 5 ขั้นตอนการเชื่อมต่อที่ถูกต้อง',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ]),
              ),
            ),
          ),
          if (savedMac != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _connecting == null
                      ? () => _connect(ScannedWatch(name: savedName, mac: savedMac, rssi: -45))
                      : null,
                  icon: const Icon(Icons.bolt),
                  label: Text('เชื่อมต่อตรงกับเรือนเดิมทันที ($savedName · $savedMac)'),
                ),
              ),
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

  void _showTroubleshootDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('5 ขั้นตอนเชื่อมต่อ F520Pro ให้ติด 100%'),
        content: const SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text('1. ปิดแอป Joeme Fit / H Band เดิม: นาฬิกาเชื่อมต่อได้ครั้งละ 1 แอป หากมีแอปเดิมเปิดอยู่เบื้องหลัง ให้บังคับหยุด (Force Stop) หรือถอนการติดตั้งก่อน\n'),
            Text('2. ห้ามจับคู่ในเมนู Bluetooth ของมือถือโดยตรง: ไปที่ ตั้งค่าโทรศัพท์ > Bluetooth หากมีชื่อ F520Pro ค้างอยู่ ให้กด "เลิกจับคู่ / ลืมอุปกรณ์" แล้วปิด-เปิด Bluetooth ใหม่ 1 ครั้ง\n'),
            Text('3. ปลุกหน้าจอนาฬิกาให้สว่าง: กดปุ่มข้างตัวเรือนนาฬิกาให้หน้าจอติด และวางห่างโทรศัพท์ไม่เกิน 30 ซม. ขณะกดเชื่อมต่อ\n'),
            Text('4. เปิด Location (GPS) บนมือถือ: ระบบ Android ต้องใช้สิทธิ์ Location ร่วมกับการสแกนหาสัญญาณ BLE\n'),
            Text('5. เปิดสวิตช์ดูแลสุขภาพ 24 ชม.: ในแท็บ "ฉัน" ให้เปิดโหมด Foreground Service เพื่อป้องกันมือถือตัดบลูทูธเมื่อล็อกหน้าจอ'),
          ]),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('เข้าใจแล้ว')),
        ],
      ),
    );
  }
}
