import 'package:flutter/material.dart';

/// แบ่งระดับความดันสำหรับแสดงผลเท่านั้น (ไม่ใช่การวินิจฉัย)
/// อิงเกณฑ์แนวทางเวชปฏิบัติความดันโลหิตสูงของไทย — ปรับเกณฑ์ได้ตามที่แพทย์ของหน่วยงานกำหนด
class BpCategory {
  final String label;
  final Color color;
  const BpCategory(this.label, this.color);

  static BpCategory of(int sys, int dia) {
    if (sys >= 180 || dia >= 110) return const BpCategory('สูงมาก ควรพบแพทย์', Color(0xFFB3261E));
    if (sys >= 140 || dia >= 90) return const BpCategory('สูง', Color(0xFFE8710A));
    if (sys >= 130 || dia >= 85) return const BpCategory('ค่อนข้างสูง', Color(0xFFC9A100));
    if (sys < 90 || dia < 60) return const BpCategory('ต่ำ', Color(0xFF1A73E8));
    return const BpCategory('ปกติ', Color(0xFF188038));
  }
}
