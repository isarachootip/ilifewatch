import 'package:flutter/material.dart';

import '../app_state.dart';
import '../data/api_client.dart';
import '../data/upload_queue.dart';
import '../l10n/app_strings.dart';

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
      final code = _code.text.trim().toUpperCase();
      final res = await s.api.login(code, _pin.text.trim());
      await s.applyLogin(res, code: code);
      s.addAlerts(await UploadQueue().flush(s.api, onUnauthorized: s.markSessionExpired));
      if (mounted && Navigator.canPop(context)) Navigator.pop(context);
    } catch (e) {
      setState(() => _error = '${tr('login_fail')}: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('setup_screen_title'))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(tr('setup_guide_text')),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            decoration: InputDecoration(labelText: tr('reg_code_label'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _pin,
            obscureText: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: tr('pin_label'), border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: Text(tr('dev_server_title')),
            children: [
              TextField(controller: _server, decoration: const InputDecoration(labelText: 'Server URL')),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _consent,
            onChanged: (v) => setState(() => _consent = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(tr('pdpa_consent')),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy || !_consent ? null : _login,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: _busy ? const CircularProgressIndicator() : Text(tr('login_btn')),
            ),
          ),
        ],
      ),
    );
  }
}
