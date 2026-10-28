import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/storage/settings_controller.dart';
import '../../game/rendering/arrow_palette.dart';
import '../../models/game_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SettingsController>();
    final s = controller.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _SectionLabel('Audio & Feedback'),
          SwitchListTile(
            title: const Text('Sound effects'),
            value: s.soundEnabled,
            onChanged: controller.setSound,
          ),
          SwitchListTile(
            title: const Text('Music'),
            value: s.musicEnabled,
            onChanged: controller.setMusic,
          ),
          SwitchListTile(
            title: const Text('Haptic feedback'),
            value: s.hapticsEnabled,
            onChanged: controller.setHaptics,
          ),
          SwitchListTile(
            title: const Text('Reduced motion'),
            subtitle: const Text('Shorter, simpler animations'),
            value: s.reducedMotion,
            onChanged: controller.setReducedMotion,
          ),
          const Divider(),
          _SectionLabel('Appearance'),
          RadioGroup<AppThemeMode>(
            groupValue: s.themeMode,
            onChanged: (v) => controller.setThemeMode(v!),
            child: const Column(
              children: [
                RadioListTile<AppThemeMode>(
                  title: Text('Light'),
                  value: AppThemeMode.light,
                ),
                RadioListTile<AppThemeMode>(
                  title: Text('Warm'),
                  value: AppThemeMode.warm,
                ),
                RadioListTile<AppThemeMode>(
                  title: Text('Dark'),
                  value: AppThemeMode.dark,
                ),
              ],
            ),
          ),
          const Divider(),
          _SectionLabel('Arrow Colors'),
          RadioGroup<String>(
            groupValue: s.arrowPaletteName,
            onChanged: (v) => controller.setPalette(v!),
            child: Column(
              children: ArrowPalette.all
                  .map((p) => RadioListTile<String>(
                        title: Text(p.name),
                        value: p.name,
                        secondary: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: p.colors.values
                              .map((c) => Container(
                                    width: 12,
                                    height: 12,
                                    margin: const EdgeInsets.only(left: 2),
                                    decoration:
                                        BoxDecoration(color: c, shape: BoxShape.circle),
                                  ))
                              .toList(),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const Divider(),
          _SectionLabel('Gameplay'),
          SwitchListTile(
            title: const Text('Timed mode'),
            subtitle: const Text('Adds an optional countdown to each level'),
            value: s.timedModeEnabled,
            onChanged: controller.setTimedMode,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
      ),
    );
  }
}
