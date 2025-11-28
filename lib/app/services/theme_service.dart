import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

class ThemeService {
  static final _box = GetStorage();
  static const _key = 'themeMode';
  static final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier<ThemeMode>(getThemeMode());

  static ThemeMode getThemeMode() {
    var stored = _box.read(_key) ?? 'light';
    return stored == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }

  static void setThemeMode(Brightness brightness) {
    final mode = brightness == Brightness.dark ? 'dark' : 'light';
    _box.write(_key, mode);
    themeNotifier.value = mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
  }
}

