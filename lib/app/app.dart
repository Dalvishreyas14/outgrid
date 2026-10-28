import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/storage/progress_controller.dart';
import '../core/storage/settings_controller.dart';
import '../features/home/home_screen.dart';
import '../game/data/level_repository.dart';
import 'app_theme.dart';

class OutgridApp extends StatelessWidget {
  const OutgridApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>().settings;
    return MaterialApp(
      title: 'OUTGRID',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.forMode(settings.themeMode),
      home: const HomeScreen(),
    );
  }
}

/// Wires app-wide singletons before the UI exists. Both controllers load
/// their persisted state in `main()` prior to `runApp`, so no screen ever
/// renders with a half-loaded save.
class AppProviders extends StatelessWidget {
  final SettingsController settingsController;
  final ProgressController progressController;
  final Widget child;

  const AppProviders({
    super.key,
    required this.settingsController,
    required this.progressController,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settingsController),
        ChangeNotifierProvider.value(value: progressController),
        Provider<LevelRepository>(create: (_) => LevelRepository()),
      ],
      child: child,
    );
  }
}
