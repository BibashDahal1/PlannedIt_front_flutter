import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/data/auth_providers.dart';

class ThemeModeController extends Notifier<ThemeMode> {
  static const _storageKey = 'app_theme_mode';

  @override
  ThemeMode build() {
    _restore();
    return ThemeMode
        .light; // default until restore finishes, then stays put either way
  }

  Future<void> _restore() async {
    final raw = await ref.read(tokenStorageProvider).readRaw(_storageKey);
    if (raw == 'dark') state = ThemeMode.dark;
  }

  Future<void> toggle() async {
    final next = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = next;
    await ref
        .read(tokenStorageProvider)
        .writeRaw(_storageKey, next == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeController, ThemeMode>(
  ThemeModeController.new,
);
