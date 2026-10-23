import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/pair_screen.dart';
import 'screens/setup_screen.dart';
import 'watch/watch_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  WatchService.instance.ensureListening();
  runApp(const WatchCareApp());
}

class WatchCareApp extends StatelessWidget {
  const WatchCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0E7C86));
    return MaterialApp(
      title: 'ITE Watch Care',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
      ),
      // ตัวอักษรใหญ่ขึ้นเล็กน้อย เหมาะกับผู้สูงอายุ
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.1)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final s = AppState.instance;
          if (!s.isLoggedIn) return const SetupScreen();
          if (s.pairedMac == null) return const PairScreen();
          return const HomeScreen();
        },
      ),
    );
  }
}
