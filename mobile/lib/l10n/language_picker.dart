import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/ilife_theme.dart';
import 'app_language.dart';
import 'app_strings.dart';

/// ปุ่มสลับภาษาด่วนบนมุมขวาบนของ AppBar
class LanguagePickerButton extends StatelessWidget {
  const LanguagePickerButton({super.key});

  @override
  Widget build(BuildContext context) {
    final current = AppState.instance.language;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => showLanguagePickerSheet(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: ILifeTheme.magentaLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, size: 16, color: ILifeTheme.magenta),
            const SizedBox(width: 4),
            Text(
              current.badge,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: ILifeTheme.navy,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// แสดงแผ่นเลือกภาษา 5 ภาษา (ไทย, English, 简体中文, العربية, Deutsch)
Future<void> showLanguagePickerSheet(BuildContext context) {
  final current = AppState.instance.language;
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.translate, color: ILifeTheme.magenta),
                  const SizedBox(width: 8),
                  Text(
                    tr('select_language'),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: ILifeTheme.navy,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ...AppLanguage.values.map((lang) {
                final selected = lang == current;
                return ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  tileColor: selected ? ILifeTheme.magentaLight.withAlpha(120) : null,
                  leading: Container(
                    width: 42,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected ? ILifeTheme.magenta : ILifeTheme.scaffoldBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      lang.badge,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: selected ? Colors.white : ILifeTheme.navy,
                      ),
                    ),
                  ),
                  title: Text(
                    lang.nativeName,
                    style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                      color: ILifeTheme.navy,
                    ),
                  ),
                  subtitle: Text(
                    lang.englishName,
                    style: const TextStyle(fontSize: 12, color: ILifeTheme.textSecondary),
                  ),
                  trailing: selected
                      ? const Icon(Icons.check_circle, color: ILifeTheme.magenta)
                      : null,
                  onTap: () {
                    AppState.instance.setLanguage(lang);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        ),
      );
    },
  );
}
