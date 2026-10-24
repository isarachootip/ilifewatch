import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/api_client.dart';
import 'watch/watch_models.dart';

/// สถานะของแอป: บัญชีผู้ใช้, นาฬิกาที่จับคู่, ค่าล่าสุดจากนาฬิกา F520Pro
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState instance = AppState._();

  static const defaultServer = 'https://ilifewatch.online';

  String server = defaultServer;
  String? token;
  String? patientName;
  String? orgName;
  String? orgType; // elder_care | clinic | corporate
  UserProfile? profile;
  String? pairedMac;
  String? pairedName;
  DateTime? lastSync;

  BpReading? latestBp;
  int? latestHeartRate;
  int? latestSpo2;
  double? latestTemperature;
  int todaySteps = 0;
  int latestSleepMinutes = 0;
  int latestDeepMinutes = 0;
  int latestLightMinutes = 0;
  Map<String, dynamic>? battery;
  final List<BpReading> recentBp = [];
  final List<Map<String, dynamic>> alerts = [];

  double get distanceKm => todaySteps * 0.0007;
  int get caloriesKcal => (todaySteps * 0.04).round();
  String get sleepFormatted {
    if (latestSleepMinutes <= 0) return '00:00';
    final h = (latestSleepMinutes ~/ 60).toString().padLeft(2, '0');
    final m = (latestSleepMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  late ApiClient api = ApiClient(baseUrl: server);

  bool get isLoggedIn => token != null && profile != null;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    server = p.getString('server') ?? defaultServer;
    token = p.getString('token');
    patientName = p.getString('patientName');
    orgName = p.getString('orgName');
    orgType = p.getString('orgType');
    pairedMac = p.getString('pairedMac');
    pairedName = p.getString('pairedName');
    todaySteps = p.getInt('todaySteps') ?? 0;
    latestSleepMinutes = p.getInt('latestSleepMinutes') ?? 0;
    final ls = p.getInt('lastSync');
    lastSync = ls == null ? null : DateTime.fromMillisecondsSinceEpoch(ls);
    if (p.containsKey('heightCm')) {
      profile = UserProfile(
        isMale: p.getBool('isMale') ?? false,
        heightCm: p.getInt('heightCm')!,
        weightKg: p.getInt('weightKg') ?? 60,
        birthYear: p.getInt('birthYear') ?? 1960,
      );
    }
    api = ApiClient(baseUrl: server, token: token);
    notifyListeners();
  }

  Future<void> applyLogin(Map<String, dynamic> res) async {
    final p = await SharedPreferences.getInstance();
    token = res['token'] as String;
    final patient = Map<String, dynamic>.from(res['patient'] as Map);
    final org = Map<String, dynamic>.from(res['org'] as Map);
    patientName = patient['display_name'] as String?;
    orgName = org['name'] as String?;
    orgType = org['type'] as String?;
    profile = UserProfile(
      isMale: patient['sex'] == 'M',
      heightCm: (patient['height_cm'] ?? 160) as int,
      weightKg: (patient['weight_kg'] ?? 60) as int,
      birthYear: (patient['birth_year'] ?? 1960) as int,
    );
    await p.setString('server', server);
    await p.setString('token', token!);
    await p.setString('patientName', patientName ?? '');
    await p.setString('orgName', orgName ?? '');
    await p.setString('orgType', orgType ?? '');
    await p.setBool('isMale', profile!.isMale);
    await p.setInt('heightCm', profile!.heightCm);
    await p.setInt('weightKg', profile!.weightKg);
    await p.setInt('birthYear', profile!.birthYear);
    notifyListeners();
  }

  Future<void> setPaired(String mac, String name) async {
    pairedMac = mac;
    pairedName = name;
    final p = await SharedPreferences.getInstance();
    await p.setString('pairedMac', mac);
    await p.setString('pairedName', name);
    notifyListeners();
  }

  Future<void> unpair() async {
    pairedMac = null;
    pairedName = null;
    final p = await SharedPreferences.getInstance();
    await p.remove('pairedMac');
    await p.remove('pairedName');
    notifyListeners();
  }

  Future<void> markSynced(DateTime t) async {
    lastSync = t;
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastSync', t.millisecondsSinceEpoch);
    await p.setInt('todaySteps', todaySteps);
    await p.setInt('latestSleepMinutes', latestSleepMinutes);
    notifyListeners();
  }

  void addBp(BpReading r) {
    if (!r.isValid) return;
    recentBp.insert(0, r);
    recentBp.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    if (recentBp.length > 50) recentBp.removeRange(50, recentBp.length);
    latestBp = recentBp.first;
    if (r.pulse != null && r.pulse! > 0) latestHeartRate = r.pulse;
    notifyListeners();
  }

  void setVital(String metric, double v, {DateTime? at}) {
    if (metric == 'heart_rate') latestHeartRate = v.round();
    if (metric == 'spo2') latestSpo2 = v.round();
    if (metric == 'temperature') latestTemperature = v;
    if (metric == 'steps') {
      final now = DateTime.now();
      if (at == null || (at.year == now.year && at.month == now.month && at.day == now.day)) {
        todaySteps += v.round();
      }
    }
    notifyListeners();
  }

  void resetStepsForSync() {
    todaySteps = 0;
  }

  void setSleep({required int deep, required int light}) {
    latestDeepMinutes = deep;
    latestLightMinutes = light;
    latestSleepMinutes = deep + light;
    notifyListeners();
  }

  void setBattery(Map<String, dynamic> b) {
    battery = b;
    notifyListeners();
  }

  void addAlerts(List<Map<String, dynamic>> a) {
    if (a.isEmpty) return;
    alerts.insertAll(0, a);
    notifyListeners();
  }

  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    token = null;
    profile = null;
    pairedMac = null;
    recentBp.clear();
    alerts.clear();
    notifyListeners();
  }
}
