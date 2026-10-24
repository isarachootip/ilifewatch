import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/main_shell.dart';
import 'theme/ilife_theme.dart';
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
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final lang = AppState.instance.language;
        return MaterialApp(
          title: 'iLife Watch',
          debugShowCheckedModeBanner: false,
          theme: ILifeTheme.buildTheme(),
          builder: (context, child) => Directionality(
            textDirection: lang.direction,
            child: MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.05)),
              child: child ?? const SizedBox.shrink(),
            ),
          ),
          home: const MainShell(),
        );
      },
    );
  }
}
