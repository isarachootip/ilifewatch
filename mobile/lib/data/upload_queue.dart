import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

/// คิวข้อมูลที่ยังส่งไม่สำเร็จ (เช่น ไม่มีเน็ต) เก็บไว้ในเครื่องแล้วส่งใหม่ภายหลัง
///
/// หมายเหตุ PDPA: ข้อมูลสุขภาพที่ค้างในคิวอยู่ในพื้นที่ส่วนตัวของแอป
/// สำหรับระบบจริงควรเปลี่ยนไปใช้ที่เก็บแบบเข้ารหัส (เช่น flutter_secure_storage / sqlcipher)
class UploadQueue {
  static const _key = 'pending_uploads_v1';
  static const _maxBatches = 200;

  Future<List<Map<String, dynamic>>> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_key) ?? const [];
    return raw.map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map)).toList();
  }

  Future<void> _save(List<Map<String, dynamic>> items) async {
    final p = await SharedPreferences.getInstance();
    final trimmed = items.length > _maxBatches ? items.sublist(items.length - _maxBatches) : items;
    await p.setStringList(_key, trimmed.map(jsonEncode).toList());
  }

  Future<int> get length async => (await _load()).length;

  Future<void> add(Map<String, dynamic> payload) async {
    final items = await _load();
    items.add(payload);
    await _save(items);
  }

  /// ส่งทุกชุดที่ค้าง คืนค่า alerts ที่ server ตอบกลับมา
  Future<List<Map<String, dynamic>>> flush(ApiClient api) async {
    final items = await _load();
    final alerts = <Map<String, dynamic>>[];
    while (items.isNotEmpty) {
      try {
        final res = await api.ingest(items.first);
        for (final a in (res['alerts'] as List? ?? const [])) {
          alerts.add(Map<String, dynamic>.from(a as Map));
        }
        items.removeAt(0);
        await _save(items);
      } on ApiException catch (e) {
        if (e.status >= 400 && e.status < 500 && e.status != 401 && e.status != 429) {
          items.removeAt(0); // ข้อมูลผิดรูปแบบ ส่งซ้ำก็ไม่ผ่าน
          await _save(items);
          continue;
        }
        break;
      } catch (_) {
        break; // ไม่มีเน็ต: เก็บไว้ส่งรอบหน้า
      }
    }
    return alerts;
  }
}
