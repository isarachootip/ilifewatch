import 'package:flutter/material.dart';

/// ภาษาที่รองรับในระบบ iLife Watch (5 ภาษา)
enum AppLanguage {
  th(code: 'th', nativeName: 'ไทย', englishName: 'Thai', badge: 'TH', direction: TextDirection.ltr),
  en(code: 'en', nativeName: 'English', englishName: 'English', badge: 'EN', direction: TextDirection.ltr),
  zh(code: 'zh', nativeName: '简体中文', englishName: 'Chinese', badge: '中文', direction: TextDirection.ltr),
  ar(code: 'ar', nativeName: 'العربية', englishName: 'Arabic', badge: 'عربي', direction: TextDirection.rtl),
  de(code: 'de', nativeName: 'Deutsch', englishName: 'German', badge: 'DE', direction: TextDirection.ltr);

  const AppLanguage({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.badge,
    required this.direction,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final String badge;
  final TextDirection direction;

  bool get isRtl => direction == TextDirection.rtl;

  static AppLanguage fromCode(String? code) {
    for (final lang in AppLanguage.values) {
      if (lang.code == code) return lang;
    }
    return AppLanguage.th;
  }
}
