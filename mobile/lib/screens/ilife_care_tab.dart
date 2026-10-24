import 'package:flutter/material.dart';

import '../theme/ilife_theme.dart';

/// แท็บที่ 3: iLife Care (จำลองหน้าแอป iLife Care จากวิดีโอต้นฉบับ)
class ILifeCareTab extends StatelessWidget {
  const ILifeCareTab({super.key});

  static const _products = [
    ('ถุงใส่น้ำดื่มอัลคาไลน์ ไฮโดรเจน 1 ลิตร', 'อาหารสุขภาพ', '55 บาท', Color(0xFFE3F2FD), Icons.water_drop),
    ('ถุงใส่น้ำดื่มอัลคาไลน์ ไฮโดรเจน 5 ลิตร', 'อาหารสุขภาพ', '70 บาท', Color(0xFFE0F7FA), Icons.water),
    ('ถุงใส่น้ำดื่มอัลคาไลน์ ชุด 1 ลิตร + 5 ลิตร', 'อาหารสุขภาพ', '125 บาท', Color(0xFFE8F5E9), Icons.local_drink),
    ('บริการน้ำอัลคาไลน์ ไฮโดรเจน 5 ลิตร', 'ผลิตภัณฑ์', '180 บาท', Color(0xFFE1F5FE), Icons.opacity),
    ('แมงกะพรุนปรุงรสเพื่อสุขภาพ', 'ผลิตภัณฑ์', '199 บาท', Color(0xFFFCE4EC), Icons.restaurant),
    ('น้ำจิ้มสุกี้สูตรโซเดียมต่ำ', 'ผลิตภัณฑ์', '200 บาท', Color(0xFFFFF3E0), Icons.soup_kitchen),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const ILifeLogo(fontSize: 26),
        actions: [
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('ตะกร้าสินค้า iLife Care')),
            ),
            icon: const Icon(Icons.shopping_cart_outlined, color: ILifeTheme.navy),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                Expanded(child: Text('ค้นหาสินค้าและบริการสุขภาพ iLife...', style: TextStyle(color: ILifeTheme.textSecondary))),
                Icon(Icons.search, color: ILifeTheme.navy),
                SizedBox(width: 10),
                Icon(Icons.tune, color: ILifeTheme.navy),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0077B6), Color(0xFF00A896)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('น้ำดื่มอัลคาไลน์ ไฮโดรเจน', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text('ดูแลสมดุลร่างกายควบคู่กับการวัดความดันด้วย iLife Watch', style: TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.water_drop, color: Colors.white, size: 44),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.grid_view_rounded, size: 18, color: ILifeTheme.magenta),
                      SizedBox(width: 6),
                      Text('เมนูลัด iLife Care', style: TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.25,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    children: const [
                      _ShortcutTile(icon: Icons.water_drop_outlined, color: Color(0xFF0288D1), label: 'น้ำดื่ม ไอไลฟ์'),
                      _ShortcutTile(icon: Icons.storefront_outlined, color: Color(0xFFF57C00), label: 'ร้านค้า'),
                      _ShortcutTile(icon: Icons.shopping_bag_outlined, color: ILifeTheme.magenta, label: 'ซื้อสินค้า'),
                      _ShortcutTile(icon: Icons.restaurant_menu, color: Color(0xFF7B1FA2), label: 'สั่งอาหาร'),
                      _ShortcutTile(icon: Icons.eco_outlined, color: ILifeTheme.teal, label: 'สดจากไร่'),
                      _ShortcutTile(icon: Icons.support_agent, color: ILifeTheme.navy, label: 'ปรึกษาผู้ดูแล'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ผลิตภัณฑ์เพื่อสุขภาพ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
              Text('ดูทั้งหมด >', style: TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _products.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (context, i) {
              final (title, cat, price, bg, icon) = _products[i];
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('เลือก $title ($price)')),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
                            child: Icon(icon, size: 54, color: ILifeTheme.navy.withAlpha(180)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ILifeTheme.navy)),
                        const SizedBox(height: 2),
                        Text(cat, style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
                        const SizedBox(height: 4),
                        Text(price, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: ILifeTheme.navy)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: ILifeTheme.scaffoldBg, borderRadius: BorderRadius.circular(12)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ILifeTheme.navy)),
        ],
      ),
    );
  }
}
