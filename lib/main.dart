import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/sketch_colors.dart';
import 'core/theme/theme_mode_provider.dart';
import 'core/widgets/app_notifications_gate.dart';
import 'core/widgets/paper_background.dart';
// import 'core/widgets/app_notifications_gate.dart';

void main() {
  runApp(const ProviderScope(child: PlannedItApp()));
}

class PlannedItApp extends ConsumerWidget {
  const PlannedItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    SketchColors.sync(mode == ThemeMode.dark);

    return AppNotificationsGate(
      child: MaterialApp.router(
        title: 'PlannedIT',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: mode,
        scaffoldMessengerKey: rootScaffoldMessengerKey,
        routerConfig: appRouter,
        builder: (context, child) =>
            PaperBackground(child: child ?? const SizedBox()),
      ),
    );
  }
}
