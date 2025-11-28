import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService.themeNotifier,
        builder: (context, themeMode, child) {
          final isDark = themeMode == ThemeMode.dark;
          return SwitchListTile(
            secondary: Icon(
              Icons.brightness_6,
              color: Theme.of(context).colorScheme.primary,
            ),
            title: const Text('Dark Mode'),
            subtitle: const Text('Switch between Light and Dark themes'),
            value: isDark,
            onChanged: (bool value) {
              final brightness = value ? Brightness.dark : Brightness.light;
              ThemeService.setThemeMode(brightness);
            },
          );
        },
      ),
    );
  }
}

