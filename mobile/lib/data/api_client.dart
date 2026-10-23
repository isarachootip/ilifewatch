import 'dart:convert';

import 'package:http/http.dart' as http;

/// เรียก backend (ดู backend/app/main.py)
class ApiClient {
  ApiClient({required this.baseUrl, this.token});

  final String baseUrl;
  String? token;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Uri _u(String path) => Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');

  /// เข้าสู่ระบบด้วยรหัสลงทะเบียนที่เจ้าหน้าที่ (ศูนย์ดูแล/คลินิก/HR) ออกให้
  Future<Map<String, dynamic>> login(String enrollmentCode, String pin) async {
    final r = await http
        .post(_u('/v1/auth/login'),
            headers: _headers, body: jsonEncode({'enrollment_code': enrollmentCode, 'pin': pin}))
        .timeout(const Duration(seconds: 20));
    final body = _decode(r);
    token = body['token'] as String;
    return body;
  }

  /// ส่งข้อมูลจากนาฬิกาขึ้นเซิร์ฟเวอร์ (backend กันข้อมูลซ้ำให้)
  Future<Map<String, dynamic>> ingest(Map<String, dynamic> payload) async {
    final r = await http
        .post(_u('/v1/ingest'), headers: _headers, body: jsonEncode(payload))
        .timeout(const Duration(seconds: 60));
    return _decode(r);
  }

  Future<Map<String, dynamic>> summary() async {
    final r = await http.get(_u('/v1/me/summary'), headers: _headers).timeout(const Duration(seconds: 20));
    return _decode(r);
  }

  Map<String, dynamic> _decode(http.Response r) {
    final body = r.body.isEmpty ? <String, dynamic>{} : jsonDecode(utf8.decode(r.bodyBytes));
    if (r.statusCode >= 400) {
      final msg = body is Map && body['detail'] != null ? body['detail'].toString() : 'HTTP ${r.statusCode}';
      throw ApiException(r.statusCode, msg);
    }
    return Map<String, dynamic>.from(body as Map);
  }
}

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;
  @override
  String toString() => message;
}
