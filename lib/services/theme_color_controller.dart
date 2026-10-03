import 'package:flutter/material.dart';

import 'database_service.dart';

class ThemeColorController extends ValueNotifier<Color> {
  ThemeColorController._() : super(defaultColor);

  static final instance = ThemeColorController._();
  static const defaultColor = Color(0xFFB07A1B);
  static const _settingKey = 'theme_seed_color';

  Future<void> load() async {
    final stored = await DatabaseService.instance.getSetting(_settingKey);
    if (stored == null) return;
    final parsed = int.tryParse(stored);
    if (parsed != null) value = Color(parsed);
  }

  Future<void> setColor(Color color) async {
    value = color;
    await DatabaseService.instance.setSetting(_settingKey, color.toARGB32().toString());
  }

  Future<void> reset() => setColor(defaultColor);
}
