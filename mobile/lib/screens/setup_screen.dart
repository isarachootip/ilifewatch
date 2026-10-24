import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api_client.dart';

/// เข้าสู่ระบบด้วยรหัสลงทะเบียนที่เจ้าหน้าที่ออกให้
/// (ศูนย์ดูแลผู้สูงอายุ / คลินิก / ฝ่าย HR สร้างผู้ใช้และรหัสในระบบหลังบ้าน)
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  final _code = TextEditingController();
  final _pin = TextEditingController();
  final _server = TextEditingController(text: AppState.instance.server);
  bool _consent = false;
  bool _busy = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final s = AppState.instance;
    s.server = _server.text.trim();
    s.api = ApiClient(baseUrl: s.server);
    try {
      final res = await s.api.login(_code.text.trim(), _pin.text.trim());
      await s.applyLogin(res);
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = 'เข้าสู่ระบบไม่สำเร็จ: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ลงทะเบียนใช้งาน')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('กรอกรหัสที่ได้รับจากศูนย์ดูแล คลินิก หรือฝ่ายบุคคล'),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'รหัสลงทะเบียน', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('ตั้งค่าเซิร์ฟเวอร์ (สำหรับผู้พัฒนา)'),
            children: [
              TextField(controller: _server, decoration: const InputDecoration(labelText: 'Server URL')),
            ],
          ),
          const SizedBox(height: 12),
          // PDPA: ข้อมูลสุขภาพเป็นข้อมูลอ่อนไหว ต้องขอความยินยอมโดยชัดแจ้ง
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'ข้าพเจ้ายินยอมให้เก็บและส่งข้อมูลสุขภาพจากนาฬิกา (ความดัน ชีพจร ECG ออกซิเจน การนอน) '
              'ให้หน่วยงานที่ให้บริการ เพื่อใช้ติดตามสุขภาพของข้าพเจ้า ตามนโยบายความเป็นส่วนตัว',
            ),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !_consent ? null : _login,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _busy ? const CircularProgressIndicator() : const Text('เข้าสู่ระบบ'),
            ),
          ),
        ],
      ),
    );
  }
}
