import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/groups/data/groups_providers.dart';
import '../realtime/notification_inbox_provider.dart';
import 'sketch_icon.dart';
import '../theme/sketch_colors.dart';
import '../theme/theme_mode_provider.dart';

class _NavItem {
  final String? asset;
  final String label;

  const _NavItem({required this.asset, required this.label});
}

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;
  const MainScaffold({super.key, required this.navigationShell});

  static const _tabs = [
    _NavItem(asset: 'nav_home', label: 'Home'),
    _NavItem(asset: 'nav_compass', label: 'Explore'),
    _NavItem(asset: null, label: 'Post'),
    _NavItem(asset: 'nav_chat', label: 'Chat'),
    _NavItem(asset: 'nav_profile', label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(themeModeProvider);
    ref.watch(myGroupsProvider);
    final unreadChatCount = ref.watch(
      notificationInboxProvider.select((inbox) => inbox.unreadChatMessageCount),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: navigationShell,
      bottomNavigationBar: DecoratedBox(
        // no `const` here: SketchColors.ink is a getter now
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SketchColors.ink, width: 1.4)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 66,
            child: Row(
              children: List.generate(5, (index) {
                final selected = navigationShell.currentIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => navigationShell.goBranch(
                      index,
                      initialLocation: index == navigationShell.currentIndex,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: selected ? 1 : 0.45,
                          child: index == 2
                              ? const _PlusGlyph()
                              : index == 3
                              ? Badge(
                                  isLabelVisible: unreadChatCount > 0,
                                  label: Text(
                                    unreadChatCount > 99
                                        ? '99+'
                                        : '$unreadChatCount',
                                  ),
                                  child: SketchIcon(
                                    _tabs[index].asset as String,
                                    size: 24,
                                  ),
                                )
                              : SketchIcon(
                                  _tabs[index].asset as String,
                                  size: 24,
                                ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tabs[index].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: SketchColors.ink.withValues(
                              alpha: selected ? 1 : 0.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusGlyph extends StatelessWidget {
  const _PlusGlyph();
  @override
  Widget build(BuildContext context) {
    return const SketchIcon('plus', size: 24);
  }
}
