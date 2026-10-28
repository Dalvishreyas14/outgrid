import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/storage/progress_controller.dart';
import 'core/storage/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsController = SettingsController();
  final progressController = ProgressController();
  await Future.wait([settingsController.load(), progressController.load()]);

  runApp(AppProviders(
    settingsController: settingsController,
    progressController: progressController,
    child: const OutgridApp(),
  ));
}
