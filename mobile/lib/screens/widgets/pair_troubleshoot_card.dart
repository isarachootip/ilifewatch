import 'package:flutter/material.dart';

/// การ์ดคำแนะนำและหน้าต่างวิธีแก้ไขปัญหาเชื่อมต่อ F520Pro
class PairTroubleshootBanner extends StatelessWidget {
  const PairTroubleshootBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => showPairTroubleshootDialog(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFFFE082)),
          ),
          child: const Row(children: [
            Icon(Icons.tips_and_updates, color: Color(0xFFF57F17)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'เชื่อมต่อไม่ติด / ค้นหาไม่เจอ? แตะดู 5 ขั้นตอนการเชื่อมต่อที่ถูกต้อง',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
            Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

void showPairTroubleshootDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('5 ขั้นตอนเชื่อมต่อ F520Pro ให้ติด 100%'),
      content: const SingleChildScrollView(
        child: Text(
          '1. ปิดแอป Joeme Fit / H Band เดิม: นาฬิกาเชื่อมต่อได้ครั้งละ 1 แอป ให้บังคับหยุด (Force Stop) หรือถอนการติดตั้งก่อน\n\n'
          '2. ห้ามจับคู่ในเมนู Bluetooth ของมือถือโดยตรง: ไปที่ ตั้งค่า > Bluetooth หากมีชื่อ F520Pro ค้างอยู่ ให้กด "เลิกจับคู่ / ลืมอุปกรณ์" แล้วปิด-เปิด Bluetooth ใหม่\n\n'
          '3. ปลุกหน้าจอนาฬิกาให้สว่าง: กดปุ่มข้างตัวเรือนให้หน้าจอติด และวางใกล้โทรศัพท์ไม่เกิน 30 ซม.\n\n'
          '4. เปิด Location (GPS) บนมือถือ: ระบบ Android ต้องใช้สิทธิ์ Location ร่วมกับการสแกนสัญญาณ BLE\n\n'
          '5. เปิดสวิตช์ดูแลสุขภาพ 24 ชม.: ในแท็บ "ฉัน" เพื่อป้องกันมือถือตัดบลูทูธเมื่อล็อกหน้าจอ',
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('เข้าใจแล้ว'))],
    ),
  );
}
