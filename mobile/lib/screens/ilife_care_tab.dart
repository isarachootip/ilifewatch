import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../l10n/language_picker.dart';
import '../theme/ilife_theme.dart';

/// แท็บที่ 3: iLife Care (จำลองหน้าแอป iLife Care จากวิดีโอต้นฉบับ)
class ILifeCareTab extends StatelessWidget {
  const ILifeCareTab({super.key});

  static const _products = [
    ('prod_1_title', 'cat_health_food', 55, Color(0xFFE3F2FD), Icons.water_drop),
    ('prod_2_title', 'cat_health_food', 70, Color(0xFFE0F7FA), Icons.water),
    ('prod_3_title', 'cat_health_food', 125, Color(0xFFE8F5E9), Icons.local_drink),
    ('prod_4_title', 'cat_product', 180, Color(0xFFE1F5FE), Icons.opacity),
    ('prod_5_title', 'cat_product', 199, Color(0xFFFCE4EC), Icons.restaurant),
    ('prod_6_title', 'cat_product', 200, Color(0xFFFFF3E0), Icons.soup_kitchen),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const ILifeLogo(fontSize: 26),
        actions: [
          const LanguagePickerButton(),
          IconButton(
            onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('cart_snack'))),
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
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(child: Text(tr('search_care_hint'), style: const TextStyle(color: ILifeTheme.textSecondary))),
                const Icon(Icons.search, color: ILifeTheme.navy),
                const SizedBox(width: 10),
                const Icon(Icons.tune, color: ILifeTheme.navy),
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
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('banner_alkaline_title'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text(tr('banner_alkaline_sub'), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.water_drop, color: Colors.white, size: 44),
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
                  Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, size: 18, color: ILifeTheme.magenta),
                      const SizedBox(width: 6),
                      Text(tr('shortcuts_title'), style: const TextStyle(fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
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
                    children: [
                      _ShortcutTile(icon: Icons.water_drop_outlined, color: const Color(0xFF0288D1), label: tr('sc_water')),
                      _ShortcutTile(icon: Icons.storefront_outlined, color: const Color(0xFFF57C00), label: tr('sc_store')),
                      _ShortcutTile(icon: Icons.shopping_bag_outlined, color: ILifeTheme.magenta, label: tr('sc_buy')),
                      _ShortcutTile(icon: Icons.restaurant_menu, color: const Color(0xFF7B1FA2), label: tr('sc_food')),
                      _ShortcutTile(icon: Icons.eco_outlined, color: ILifeTheme.teal, label: tr('sc_farm')),
                      _ShortcutTile(icon: Icons.support_agent, color: ILifeTheme.navy, label: tr('sc_consult')),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(tr('health_products_title'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ILifeTheme.navy)),
              Text(tr('view_all'), style: const TextStyle(fontSize: 12, color: ILifeTheme.teal, fontWeight: FontWeight.w700)),
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
              final (titleKey, catKey, amount, bg, icon) = _products[i];
              final title = tr(titleKey);
              final price = '$amount ${tr('currency_baht')}';
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${tr('selected_item')}: $title ($price)')),
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
                        Text(tr(catKey), style: const TextStyle(fontSize: 11, color: ILifeTheme.textSecondary)),
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
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ILifeTheme.navy)),
        ],
      ),
    );
  }
}
