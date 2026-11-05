// โมเดลข้อมูลที่ได้จากนาฬิกา F520Pro (ผ่าน Veepoo SDK)
// ทุก event จากฝั่ง native จะเป็น Map ที่มี key "type" เสมอ

class ScannedWatch {
  final String name;
  final String mac;
  final int rssi;
  final bool isVp;
  ScannedWatch({required this.name, required this.mac, required this.rssi, this.isVp = false});

  factory ScannedWatch.fromMap(Map m) => ScannedWatch(
        name: (m['name'] ?? '') as String,
        mac: (m['mac'] ?? '') as String,
        rssi: (m['rssi'] ?? 0) as int,
        isVp: m['isVp'] == true,
      );

  bool isWatchCandidate({String? pairedMac}) {
    if (pairedMac != null && mac.toUpperCase() == pairedMac.toUpperCase()) return true;
    final n = name.trim().toUpperCase();
    const blocked = ['CAR MULTIMEDIA', 'SHOKZ', 'OPENDOTS', 'AIRPODS', 'BUDS', 'SPEAKER', 'HANDSFREE', 'AUDIO', 'TV', 'IDEA'];
    if (blocked.any(n.contains)) return false;
    if (isVp) return true;
    const watchKeys = ['F520', 'ILIFE', 'VEEPOO', 'JOEME', 'HBAND', 'H BAND', 'WATCH', 'E500', 'E400', 'ET5', 'ET4', 'G08', 'RIG'];
    return watchKeys.any(n.contains);
  }

  bool get isPrimaryF520 => name.toUpperCase().contains('F520') || isVp;
}

enum WatchConnection { disconnected, connecting, connected, ready, failed }

WatchConnection connectionFromString(String s) => switch (s) {
      'connecting' => WatchConnection.connecting,
      'connected' => WatchConnection.connected,
      'ready' => WatchConnection.ready, // เชื่อมต่อ + ยืนยันรหัสผ่านสำเร็จ พร้อมสั่งงาน
      'failed' => WatchConnection.failed,
      _ => WatchConnection.disconnected,
    };

/// ผลวัดความดัน 1 ครั้ง
class BpReading {
  final DateTime measuredAt;
  final int systolic;
  final int diastolic;
  final int? pulse;

  /// 'cuff' = ปั๊มลม (ถุงลมในสาย), 'ppg' = เซนเซอร์แสง
  final String method;

  /// สถานะจาก SDK เช่น SUCCESS, POSTURE_ERROR, NOT_REMAINING_STATIONARY
  final String status;

  /// ค่าความน่าเชื่อถือของผล (ถ้ามี)
  final int? credibility;

  /// 'live' = สั่งวัดจากแอป, 'watch' = ผู้ใช้กดวัดบนนาฬิกาเอง, 'auto' = วัดอัตโนมัติ
  final String source;

  BpReading({
    required this.measuredAt,
    required this.systolic,
    required this.diastolic,
    this.pulse,
    required this.method,
    required this.status,
    this.credibility,
    required this.source,
  });

  bool get isValid => systolic > 0 && diastolic > 0 && systolic > diastolic;

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toUtc().toIso8601String(),
        'systolic': systolic,
        'diastolic': diastolic,
        'pulse': pulse,
        'method': method,
        'status': status,
        'credibility': credibility,
        'source': source,
      };
}

/// ผลการวัด ECG 1 ครั้ง (เก็บ waveform ดิบไว้ส่งเซิร์ฟเวอร์)
class EcgRecord {
  final DateTime measuredAt;
  final int durationSec, sampleRateHz;
  final int? avgHeartRate, avgHrv, avgQt, avgRespRate;
  final List<int> waveform;

  EcgRecord({
    required this.measuredAt,
    required this.durationSec,
    required this.sampleRateHz,
    this.avgHeartRate,
    this.avgHrv,
    this.avgQt,
    this.avgRespRate,
    required this.waveform,
  });

  Map<String, dynamic> toJson() => {
        'measured_at': measuredAt.toUtc().toIso8601String(),
        'duration_sec': durationSec,
        'sample_rate_hz': sampleRateHz,
        'avg_heart_rate': avgHeartRate,
        'avg_hrv': avgHrv,
        'avg_qt': avgQt,
        'avg_resp_rate': avgRespRate,
        'waveform': waveform,
      };
}

/// ค่าสุขภาพแบบอนุกรมเวลา (ชีพจร, SpO2, ก้าว, อุณหภูมิ ฯลฯ)
class VitalSample {
  final DateTime at;
  final String metric; // heart_rate, spo2, steps, temperature, hrv, stress
  final double value;
  VitalSample(this.at, this.metric, this.value);

  bool get isValid => switch (metric) {
        'heart_rate' => value >= 20 && value <= 260,
        'spo2' => value >= 50 && value <= 100,
        'temperature' => value >= 30.0 && value <= 45.0,
        'steps' => value >= 0 && value <= 200000,
        'stress' => value >= 0 && value <= 100,
        'hrv' => value >= 0 && value <= 300,
        _ => false,
      };

  Map<String, dynamic> toJson() =>
      {'at': at.toUtc().toIso8601String(), 'metric': metric, 'value': value};
}

class SleepSession {
  final DateTime start, end;
  final int deepMinutes, lightMinutes, wakeCount;
  final int? quality;

  /// 1 ตัวอักษรต่อ 5 นาที (0=หลับตื้น 1=หลับลึก 2=ตื่น) ตามรูปแบบของ SDK
  final String? curve;

  SleepSession({
    required this.start,
    required this.end,
    required this.deepMinutes,
    required this.lightMinutes,
    required this.wakeCount,
    this.quality,
    this.curve,
  });

  Map<String, dynamic> toJson() => {
        'start': start.toUtc().toIso8601String(),
        'end': end.toUtc().toIso8601String(),
        'deep_minutes': deepMinutes,
        'light_minutes': lightMinutes,
        'wake_count': wakeCount,
        'quality': quality,
        'curve': curve,
      };
}

class UserProfile {
  final bool isMale;
  final int heightCm, weightKg, birthYear, stepGoal;
  UserProfile({
    required this.isMale,
    required this.heightCm,
    required this.weightKg,
    required this.birthYear,
    this.stepGoal = 6000,
  });

  int get age => DateTime.now().year - birthYear;

  Map<String, dynamic> toMap() => {
        'isMale': isMale,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'birthYear': birthYear,
        'age': age,
        'stepGoal': stepGoal,
      };
}

/// แปลงเวลาที่ฝั่ง native ส่งมา (epoch วินาที หรือ "yyyy-MM-dd HH:mm[:ss]")
DateTime parseWatchTime(dynamic v) {
  if (v is int) {
    return DateTime.fromMillisecondsSinceEpoch(v * 1000);
  }
  if (v is String && v.isNotEmpty) {
    final s = v.replaceAll('/', '-');
    final withSeconds = s.length == 16 ? '$s:00' : s;
    return DateTime.tryParse(withSeconds.replaceFirst(' ', 'T')) ?? DateTime.now();
  }
  return DateTime.now();
}
