import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';

/// แบ่งระดับความดันสำหรับแสดงผลเท่านั้น (ไม่ใช่การวินิจฉัย)
/// อิงเกณฑ์แนวทางเวชปฏิบัติความดันโลหิตสูงของไทย — ปรับเกณฑ์ได้ตามที่แพทย์ของหน่วยงานกำหนด
class BpCategory {
  final String label;
  final Color color;
  const BpCategory(this.label, this.color);

  static BpCategory of(int sys, int dia) {
    if (sys >= 180 || dia >= 110) return BpCategory(tr('bp_very_high'), const Color(0xFFB3261E));
    if (sys >= 140 || dia >= 90) return BpCategory(tr('bp_high'), const Color(0xFFE8710A));
    if (sys >= 130 || dia >= 85) return BpCategory(tr('bp_elevated'), const Color(0xFFC9A100));
    if (sys < 90 || dia < 60) return BpCategory(tr('bp_low'), const Color(0xFF1A73E8));
    return BpCategory(tr('bp_normal'), const Color(0xFF188038));
  }
}
