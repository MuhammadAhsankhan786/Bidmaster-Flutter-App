import 'package:flutter/material.dart';
import '../services/theme_service.dart';

class ThemeToggleTile extends StatelessWidget {
  const ThemeToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeService.themeNotifier,
      builder: (context, themeMode, child) {
        final isDark = themeMode == ThemeMode.dark;
        return SwitchListTile(
          secondary: Icon(
            isDark ? Icons.dark_mode : Icons.light_mode,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: const Text('Dark Mode'),
          subtitle: Text(isDark ? 'Dark theme is enabled' : 'Light theme is enabled'),
          value: isDark,
          onChanged: (bool value) {
            final themeMode = value ? ThemeMode.dark : ThemeMode.light;
            ThemeService.setThemeMode(themeMode);
          },
        );
      },
    );
  }
}

