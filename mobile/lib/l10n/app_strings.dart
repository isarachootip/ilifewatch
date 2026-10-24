import '../app_state.dart';
import 'app_language.dart';
import 'strings_ar.dart';
import 'strings_de.dart';
import 'strings_en.dart';
import 'strings_th.dart';
import 'strings_zh.dart';

/// ตัวจัดการคำแปลภาษาปัจจุบันของระบบ (5 ภาษา: TH, EN, ZH, AR, DE)
String tr(String key, [AppLanguage? lang]) {
  final current = lang ?? AppState.instance.language;
  final map = switch (current) {
    AppLanguage.th => stringsTh,
    AppLanguage.en => stringsEn,
    AppLanguage.zh => stringsZh,
    AppLanguage.ar => stringsAr,
    AppLanguage.de => stringsDe,
  };
  return map[key] ?? stringsTh[key] ?? key;
}

/// แปลข้อความแจ้งเตือนจากเซิร์ฟเวอร์ให้ตรงตามภาษาที่ผู้ใช้เลือก
String translateAlertMessage(String raw, [AppLanguage? lang]) {
  final current = lang ?? AppState.instance.language;
  if (current == AppLanguage.th || raw.isEmpty) return raw;

  final bpVeryHigh = RegExp(r'^ความดันสูงมาก\s+(\d+/\d+\s*mmHg)$').firstMatch(raw);
  if (bpVeryHigh != null) {
    final v = bpVeryHigh.group(1)!;
    return switch (current) {
      AppLanguage.en => 'Critical High BP: $v',
      AppLanguage.zh => '血压极高：$v',
      AppLanguage.ar => 'ضغط دم مرتفع جداً: $v',
      AppLanguage.de => 'Kritisch hoher Blutdruck: $v',
      AppLanguage.th => raw,
    };
  }

  final bpHigh = RegExp(r'^ความดันสูง\s+(\d+/\d+\s*mmHg)$').firstMatch(raw);
  if (bpHigh != null) {
    final v = bpHigh.group(1)!;
    return switch (current) {
      AppLanguage.en => 'High Blood Pressure: $v',
      AppLanguage.zh => '血压偏高：$v',
      AppLanguage.ar => 'ضغط دم مرتفع: $v',
      AppLanguage.de => 'Hoher Blutdruck: $v',
      AppLanguage.th => raw,
    };
  }

  final bpLow = RegExp(r'^ความดันต่ำ\s+(\d+/\d+\s*mmHg)$').firstMatch(raw);
  if (bpLow != null) {
    final v = bpLow.group(1)!;
    return switch (current) {
      AppLanguage.en => 'Low Blood Pressure: $v',
      AppLanguage.zh => '血压偏低：$v',
      AppLanguage.ar => 'ضغط دم منخفض: $v',
      AppLanguage.de => 'Niedriger Blutdruck: $v',
      AppLanguage.th => raw,
    };
  }

  if (raw.startsWith('ออกซิเจนในเลือดต่ำกว่า')) {
    return switch (current) {
      AppLanguage.en => 'Low Blood Oxygen (SpO2): $raw',
      AppLanguage.zh => '血氧饱和度偏低：$raw',
      AppLanguage.ar => 'انخفاض أكسجين الدم (SpO2): $raw',
      AppLanguage.de => 'Niedriger Blutsauerstoff (SpO2): $raw',
      AppLanguage.th => raw,
    };
  }

  if (raw.startsWith('ชีพจรสูงกว่า') || raw.startsWith('ชีพจรต่ำกว่า')) {
    return switch (current) {
      AppLanguage.en => 'Abnormal Heart Rate Alert: $raw',
      AppLanguage.zh => '心率异常提醒：$raw',
      AppLanguage.ar => 'تنبيه معدل نبض غير طبيعي: $raw',
      AppLanguage.de => 'Warnung Herzfrequenz: $raw',
      AppLanguage.th => raw,
    };
  }

  return raw;
}
