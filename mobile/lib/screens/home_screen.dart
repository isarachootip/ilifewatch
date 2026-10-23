import 'dart:async';

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../services/sync_service.dart';
import '../watch/watch_models.dart';
import '../watch/watch_service.dart';
import 'bp_category.dart';
import 'bp_screen.dart';
import 'ecg_screen.dart';
import 'home_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _watch = WatchService.instance;
  WatchConnection _conn = WatchConnection.disconnected;
  double? _syncProgress;
  StreamSubscription? _connSub, _progSub;
  bool _reconnecting = false;

  @override
  void initState() {
    super.initState();
    _conn = _watch.state;
    _connSub = _watch.connection.listen((c) {
      setState(() => _conn = c);
      if (c == WatchConnection.disconnected) _scheduleReconnect();
    });
    _progSub = SyncService.instance.progress.stream.listen((p) {
      setState(() => _syncProgress = p >= 1 ? null : p);
    });
    if (_conn != WatchConnection.ready) _reconnect();
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

  /// สแกนหานาฬิกาที่จับคู่ไว้แล้วเชื่อมต่อใหม่
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
      // ไม่เจอนาฬิกา: ลองใหม่ภายหลัง
      await _watch.stopScan();
    } finally {
      _reconnecting = false;
    }
  }

  Future<void> _sync() async {
    try {
      await SyncService.instance.syncAll();
      _toast('ซิงค์ข้อมูลเรียบร้อย');
    } catch (e) {
      _toast('ซิงค์ไม่สำเร็จ: $e');
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final s = AppState.instance;
        final ready = _conn == WatchConnection.ready;
        return Scaffold(
          appBar: AppBar(
            title: Text(s.patientName?.isNotEmpty == true ? s.patientName! : 'สุขภาพของฉัน'),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'unpair') {
                    await _watch.disconnect();
                    await AppState.instance.unpair();
                  } else if (v == 'logout') {
                    await _watch.disconnect();
                    await AppState.instance.logout();
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'unpair', child: Text('เปลี่ยนนาฬิกา')),
                  PopupMenuItem(value: 'logout', child: Text('ออกจากระบบ')),
                ],
              ),
            ],
          ),
          body: RefreshIndicator(
            onRefresh: ready ? _sync : _reconnect,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                ConnectionBar(conn: _conn, battery: s.battery, org: s.orgName, onRetry: _reconnect),
                if (_syncProgress != null) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _syncProgress),
                  const SizedBox(height: 4),
                  Text('กำลังดึงข้อมูลจากนาฬิกา ${(_syncProgress! * 100).round()}%'),
                ],
                const SizedBox(height: 16),
                BpCard(bp: s.latestBp),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: MetricCard(label: 'ชีพจร', value: s.latestHeartRate?.toString(), unit: 'ครั้ง/นาที', icon: Icons.favorite)),
                  const SizedBox(width: 12),
                  Expanded(child: MetricCard(label: 'ออกซิเจน', value: s.latestSpo2?.toString(), unit: '%', icon: Icons.air)),
                ]),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: ready
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BpScreen()))
                      : null,
                  icon: const Icon(Icons.monitor_heart),
                  label: const Padding(padding: EdgeInsets.all(14), child: Text('วัดความดัน')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: ready
                      ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EcgScreen()))
                      : null,
                  icon: const Icon(Icons.show_chart),
                  label: const Padding(padding: EdgeInsets.all(14), child: Text('วัดคลื่นไฟฟ้าหัวใจ (ECG)')),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: ready && _syncProgress == null ? _sync : null,
                  icon: const Icon(Icons.sync),
                  label: Text(s.lastSync == null
                      ? 'ดึงข้อมูลจากนาฬิกา'
                      : 'ดึงข้อมูลล่าสุด (ครั้งก่อน ${formatShortDateTime(s.lastSync!)})'),
                ),
                if (s.alerts.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('การแจ้งเตือน', style: Theme.of(context).textTheme.titleMedium),
                  ...s.alerts.take(5).map((a) => Card(
                        color: a['level'] == 'critical' ? const Color(0xFFFDECEA) : const Color(0xFFFFF4E5),
                        child: ListTile(
                          leading: const Icon(Icons.warning_amber),
                          title: Text(a['message']?.toString() ?? ''),
                        ),
                      )),
                ],
                if (s.recentBp.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('ความดันล่าสุด', style: Theme.of(context).textTheme.titleMedium),
                  ...s.recentBp.take(10).map((r) {
                    final c = BpCategory.of(r.systolic, r.diastolic);
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(backgroundColor: c.color, radius: 6),
                      title: Text('${r.systolic}/${r.diastolic} mmHg${r.pulse != null ? '  ชีพจร ${r.pulse}' : ''}'),
                      subtitle: Text('${formatShortDateTime(r.measuredAt)} · ${r.method == 'cuff' ? 'ปั๊มลม' : 'เซนเซอร์แสง'}'),
                      trailing: Text(c.label, style: TextStyle(color: c.color)),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                Text(
                  'ค่าที่วัดจากนาฬิกาใช้ติดตามสุขภาพเบื้องต้น ไม่ใช้แทนการวินิจฉัยของแพทย์',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
