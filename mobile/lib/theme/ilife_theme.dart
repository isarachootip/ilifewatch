import 'package:flutter/material.dart';

/// ธีมสีและโลโก้ของ iLife Care / iLife Watch
class ILifeTheme {
  ILifeTheme._();

  static const Color magenta = Color(0xFFE5005A);
  static const Color magentaLight = Color(0xFFFCE4EE);
  static const Color navy = Color(0xFF1E2A4A);
  static const Color teal = Color(0xFF00A896);
  static const Color tealLight = Color(0xFFE0F5F2);
  static const Color purple = Color(0xFF7E57C2);
  static const Color orange = Color(0xFFFF7043);
  static const Color scaffoldBg = Color(0xFFF5F6FA);
  static const Color cardBg = Colors.white;
  static const Color textSecondary = Color(0xFF6B7280);

  static ThemeData buildTheme() {
    final scheme = ColorScheme.fromSeed(
      seedColor: magenta,
      primary: magenta,
      secondary: teal,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffoldBg,
      appBarTheme: const AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: navy,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: navy,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: magenta,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}

/// วิดเจ็ตโลโก้ ilife CARE ตามดีไซน์แบรนด์
class ILifeLogo extends StatelessWidget {
  const ILifeLogo({super.key, this.fontSize = 24, this.showSubtitle = true});

  final double fontSize;
  final bool showSubtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          text: TextSpan(
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              height: 1.0,
            ),
            children: const [
              TextSpan(text: 'i', style: TextStyle(color: ILifeTheme.magenta)),
              TextSpan(text: 'l', style: TextStyle(color: ILifeTheme.magenta)),
              TextSpan(text: 'ife', style: TextStyle(color: ILifeTheme.navy)),
            ],
          ),
        ),
        if (showSubtitle)
          Text(
            'CARE • WATCH',
            style: TextStyle(
              color: ILifeTheme.teal,
              fontSize: fontSize * 0.36,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
      ],
    );
  }
}
