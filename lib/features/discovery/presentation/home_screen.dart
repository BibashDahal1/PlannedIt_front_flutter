import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../activities/data/activities_providers.dart';
import '../../activities/domain/activity_post.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../join_requests/data/join_requests_providers.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../core/theme/theme_mode_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    ref.read(authControllerProvider.notifier).refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final authState = ref.watch(authControllerProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCategory = ref.watch(selectedCategoryFilterProvider);
    final feedAsync = ref.watch(activityFeedProvider(selectedCategory));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(categoriesProvider);
            ref.invalidate(activityFeedProvider(selectedCategory));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              _buildHeader(context, authState),
              const SizedBox(height: 18),
              _buildSearchBar(),
              const SizedBox(height: 20),
              categoriesAsync.when(
                data: (categories) => _CategoryRail(categories: categories),
                loading: () => const SizedBox(
                  height: 78,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Nearby Activities', style: AppTheme.heading(size: 24)),
                  GestureDetector(
                    onTap: () => context.push('/map'),
                    child: Row(
                      children: [
                        Text(
                          'See All',
                          style: TextStyle(
                            color: SketchColors.inkFaint,
                            fontSize: 14,
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 34,
                          color: SketchColors.inkFaint,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              feedAsync.when(
                data: (activities) {
                  final filtered = _query.isEmpty
                      ? activities
                      : activities
                            .where(
                              (a) => a.title.toLowerCase().contains(
                                _query.toLowerCase(),
                              ),
                            )
                            .toList();
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No open activities right now.',
                          style: TextStyle(color: SketchColors.inkFaint),
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final a in filtered) ...[
                        _ActivityCard(activity: a),
                        const SizedBox(height: 16),
                      ],
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: Text('Could not load activities: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue authState) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                'assets/images/sketch/app_logo_mark.png',
                width: 30,
                filterQuality: FilterQuality.high,
              ),
              const SizedBox(width: 8),
              Text('PlannedIT', style: AppTheme.heading(size: 32)),
            ],
          ),
        ),
        authState.when(
          data: (state) => state.isLoggedIn
              ? Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.push('/dashboard'),
                      child: const Padding(
                        padding: EdgeInsets.only(right: 14, top: 4),
                        child: SketchIcon('bell', size: 34),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/profile'),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: UserAvatar(
                          avatarUrl: state.user?.avatar,
                          radius: 17,
                        ),
                      ),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () => context.push('/login'),
                  child: Text(
                    'Log in',
                    style: TextStyle(color: SketchColors.ink),
                  ),
                ),
          loading: () => const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return SketchBox(
      seed: 2,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const SketchIcon('search', size: 34),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v),
              decoration: const InputDecoration(
                hintText: 'Search activities, location...',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends ConsumerWidget {
  final List categories;
  const _CategoryRail({required this.categories});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedCategoryFilterProvider);

    Widget tile({
      required Widget icon,
      required String label,
      required VoidCallback onTap,
      required bool isSelected,
      required int seed,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            SketchBox(
              seed: seed,
              radius: 16,
              width: 64,
              height: 64,
              fill: isSelected
                  ? SketchColors.paperFleck.withValues(alpha: 0.35)
                  : SketchColors.paper,
              child: Center(child: icon),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 70,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 96,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: tile(
              seed: 0,
              isSelected: selected == null,
              label: 'All',
              icon: const SketchAllGlyph(size: 34),
              onTap: () => ref
                  .read(selectedCategoryFilterProvider.notifier)
                  .select(null),
            ),
          ),
          for (final c in categories)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: tile(
                seed: c.id,
                isSelected: selected == c.id,
                label: c.name,
                icon: CategoryIcon(c.name, size: 34),
                onTap: () => ref
                    .read(selectedCategoryFilterProvider.notifier)
                    .select(selected == c.id ? null : c.id),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActivityCard extends ConsumerStatefulWidget {
  final ActivityPost activity;
  const _ActivityCard({required this.activity});

  @override
  ConsumerState<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends ConsumerState<_ActivityCard> {
  bool _isJoining = false;

  Future<void> _quickJoin() async {
    setState(() => _isJoining = true);
    try {
      await ref
          .read(joinRequestsRepositoryProvider)
          .sendJoinRequest(widget.activity.id);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Request sent!')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final currentUserId = ref.watch(authControllerProvider).value?.user?.id;
    final isHost = currentUserId != null && currentUserId == a.host.id;
    final iconAsset = sketchAssetForCategory(a.category.name);
    final start = a.scheduledStart;
    final when =
        'Today, ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () => context.push('/activity/${a.id}'),
      child: SketchBox(
        seed: a.id.hashCode,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SketchBox(
              seed: a.id.hashCode + 1,
              radius: 12,
              width: 56,
              height: 56,
              child: Center(
                child: iconAsset != null
                    ? SketchIcon(iconAsset, size: 34)
                    : const SketchCircleGlyph(size: 34),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  _iconLine(
                    const SketchIcon('pin', size: 34),
                    a.location.venueName ?? a.location.addressText ?? 'Nearby',
                  ),
                  _iconLine(const SketchIcon('calendar', size: 34), when),
                  _iconLine(
                    const SketchIcon('people', size: 34),
                    '${a.totalSpotsNeeded} spots needed',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isHost)
                  SketchBox(
                    seed: a.id.hashCode + 2,
                    radius: 12,
                    fill: null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    child: _isJoining
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : GestureDetector(
                            onTap: _quickJoin,
                            child: const Text(
                              'Join',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                if (a.distanceKm != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const SketchIcon('pin', size: 34),
                      const SizedBox(width: 3),
                      Text(
                        '${a.distanceKm!.toStringAsFixed(1)} km',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconLine(Widget icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
