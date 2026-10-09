import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../join_requests/presentation/requests_screen.dart';
import '../../groups/data/groups_providers.dart';
import '../../groups/domain/group_summary.dart';
import '../../groups/presentation/groups_screen.dart'; // NEW: group chats screen
import 'activity_ratings_tab.dart';
import 'cost_management_tab.dart';
import 'dashboard_widgets.dart';
import 'team_management_tab.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String? _selectedGroupId;
  int _selectedIndex = 0;
  bool _isGroupPickerOpen = false;

  Future<void> _chooseGroup(
    List<GroupSummary> groups,
    String selectedGroupId,
  ) async {
    if (_isGroupPickerOpen) return;
    _isGroupPickerOpen = true;
    try {
      final selectedId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  'Choose an activity group',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              for (final group in groups)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SketchBox(
                    seed: group.id.hashCode,
                    radius: 16,
                    padding: const EdgeInsets.all(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => Navigator.of(context).pop(group.id),
                      child: Row(
                        children: [
                          SketchBox(
                            seed: group.id.hashCode + 1,
                            radius: 12,
                            width: 48,
                            height: 48,
                            child: Center(
                              child: GroupActivityIcon(
                                groupId: group.id,
                                size: 32,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  group.activityTitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text('${group.memberCount} members'),
                              ],
                            ),
                          ),
                          if (group.id == selectedGroupId)
                            Icon(Icons.check_circle, color: SketchColors.ink),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      if (selectedId != null && mounted) {
        setState(() => _selectedGroupId = selectedId);
      }
    } finally {
      _isGroupPickerOpen = false;
    }
  }

  void _selectTab(int index) {
    final groupId = _selectedGroupId;
    if (index == 1 && groupId != null) {
      ref.invalidate(groupExpensesProvider);
    }
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(myGroupsProvider);

    // Tabs 3 (requests) and 4 (group chats) are separate screens that
    // replace the dashboard body. If GroupsScreen has no AppBar of its own,
    // change this to `_selectedIndex == 3` so the dashboard bar still shows.
    final isSeparateScreen = _selectedIndex == 3 || _selectedIndex == 4;

    return Scaffold(
      appBar: isSeparateScreen
          ? null
          : AppBar(title: const Text('Activity Dashboard')),
      body: _selectedIndex == 3
          ? const RequestsScreen()
          : _selectedIndex == 4
          ? const GroupsScreen()
          : groupsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => DashboardError(
                message:
                    'Could not load groups: ${extractApiErrorMessage(error)}',
                onRetry: () => ref.invalidate(myGroupsProvider),
              ),
              data: (groups) {
                if (groups.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Your activity groups will appear here.'),
                    ),
                  );
                }

                final selectedGroup = groups.firstWhere(
                  (group) => group.id == _selectedGroupId,
                  orElse: () => groups.first,
                );
                if (_selectedGroupId != selectedGroup.id) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _selectedGroupId = selectedGroup.id);
                    }
                  });
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                      child: SketchBox(
                        seed: selectedGroup.id.hashCode,
                        radius: 16,
                        padding: const EdgeInsets.all(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _chooseGroup(groups, selectedGroup.id),
                          child: Row(
                            children: [
                              SketchBox(
                                seed: selectedGroup.id.hashCode + 1,
                                radius: 12,
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: GroupActivityIcon(
                                    groupId: selectedGroup.id,
                                    size: 34,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Activity group',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                    Text(
                                      selectedGroup.activityTitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.expand_more),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          TeamManagementTab(
                            key: ValueKey('teams-${selectedGroup.id}'),
                            groupId: selectedGroup.id,
                          ),
                          CostManagementTab(
                            key: ValueKey('costs-${selectedGroup.id}'),
                            groupId: selectedGroup.id,
                            isActive: _selectedIndex == 1,
                          ),
                          ActivityRatingsTab(
                            key: ValueKey('ratings-${selectedGroup.id}'),
                            groupId: selectedGroup.id,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: SketchColors.ink, width: 1.4)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 96,
            child: Row(
              children: [
                Expanded(
                  child: Center(
                    child: _DashboardNavItem(
                      imagePath: 'assets/images/sketch/dashboard_groups.png',
                      label: 'Groups',
                      selected: _selectedIndex == 0,
                      onTap: () => _selectTab(0),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _DashboardNavItem(
                      asset: 'dashboard_cost_full',
                      label: 'Costs',
                      selected: _selectedIndex == 1,
                      onTap: () => _selectTab(1),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _DashboardNavItem(
                      imagePath: 'assets/images/sketch/ratings_full.png',
                      label: 'Rate members',
                      selected: _selectedIndex == 2,
                      onTap: () => _selectTab(2),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _DashboardNavItem(
                      imagePath: 'assets/images/sketch/Requests.png',
                      label: 'Incoming Requests',
                      selected: _selectedIndex == 3,
                      onTap: () => _selectTab(3),
                    ),
                  ),
                ),
                // NEW: Group chats tab (opens GroupsScreen)
                Expanded(
                  child: Center(
                    child: _DashboardNavItem(
                      asset: 'chat_management',
                      label: 'Group chats',
                      selected: _selectedIndex == 4,
                      onTap: () => _selectTab(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The active tab is indicated by the icon only; SketchIcon applies the
/// current theme's ink color without changing the tab background.
class _DashboardNavItem extends StatelessWidget {
  final String? asset;
  final String? imagePath;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DashboardNavItem({
    this.asset,
    this.imagePath,
    this.label = '',
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          child: Opacity(
            opacity: selected ? 1 : 0.55,
            child: imagePath != null
                ? ColorFiltered(
                    colorFilter: ColorFilter.mode(
                      SketchColors.ink,
                      BlendMode.srcIn,
                    ),
                    child: Image.asset(
                      imagePath!,
                      width: 56, // reduced from 70 to fit five tabs
                      height: 62, // reduced from 76
                      fit: BoxFit.contain,
                    ),
                  )
                : SketchIcon(asset!, size: 52), // reduced from 66
          ),
        ),
      ),
    );
  }
}
