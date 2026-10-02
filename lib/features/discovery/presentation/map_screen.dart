import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config/map_config.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../shared/models/activity_location.dart';
import '../../activities/data/activities_providers.dart';
import '../../activities/domain/activity_post.dart';
import '../../activities/presentation/widgets/activity_location_map.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../places/data/places_providers.dart';
import '../../places/domain/place_result.dart';
import '../../places/presentation/location_picker_screen.dart';
import '../../../core/theme/theme_mode_provider.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _radiusOptions = [2.0, 5.0, 10.0, 25.0];

  final _mapController = MapController();
  bool _mapReady = false;
  ({LatLng point, double zoom})? _pendingMove;

  LatLng? _searchCenter;
  LatLng _mapCenter = MapConfig.fallbackCenter;
  LatLng? _userLocation;
  double _radiusKm = 10;
  int? _categoryId;
  bool _showSearchArea = false;
  List<ActivityPost> _lastActivities = const [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final location = await ref
        .read(locationServiceProvider)
        .getCurrentLocation();
    if (!mounted) return;
    final center = location ?? MapConfig.fallbackCenter;
    setState(() {
      _userLocation = location;
      _searchCenter = center;
    });
    _moveMap(center, _zoomForRadius(_radiusKm));
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location unavailable. Showing the default area; use search to go elsewhere.',
          ),
        ),
      );
    }
  }

  double _zoomForRadius(double km) =>
      (14.6 - log(km) / ln2).clamp(8.0, 17.0).toDouble();

  void _moveMap(LatLng point, double zoom) {
    _mapCenter = point;
    if (_mapReady) {
      _mapController.move(point, zoom);
    } else {
      _pendingMove = (point: point, zoom: zoom);
    }
  }

  void _onMapReady() {
    _mapReady = true;
    final pending = _pendingMove;
    if (pending != null) {
      _mapController.move(pending.point, pending.zoom);
      _pendingMove = null;
    }
  }

  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _mapCenter = camera.center;
    final searchCenter = _searchCenter;
    if (!hasGesture || searchCenter == null) return;
    final movedKm = const Distance(
      roundResult: false,
    ).as(LengthUnit.Kilometer, searchCenter, camera.center);
    final shouldShow = movedKm > max(0.5, _radiusKm * 0.25);
    if (shouldShow != _showSearchArea) {
      setState(() => _showSearchArea = shouldShow);
    }
  }

  Future<void> _recenterOnMe() async {
    final location = await ref
        .read(locationServiceProvider)
        .getCurrentLocation();
    if (!mounted) return;
    if (location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't get your location. Check location permission.",
          ),
        ),
      );
      return;
    }
    setState(() {
      _userLocation = location;
      _searchCenter = location;
      _showSearchArea = false;
    });
    _moveMap(location, _zoomForRadius(_radiusKm));
  }

  Future<void> _pickPlaceToExplore() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<PlaceResult>(
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              initial: PlaceResult(
                latitude: _mapCenter.latitude,
                longitude: _mapCenter.longitude,
              ),
              initialZoom: 14,
              confirmLabel: 'Explore this area',
            ),
          ),
        );
    if (result == null || !mounted) return;
    final point = LatLng(result.latitude, result.longitude);
    setState(() {
      _searchCenter = point;
      _showSearchArea = false;
    });
    _moveMap(point, _zoomForRadius(_radiusKm));
  }

  void _searchThisArea() {
    setState(() {
      _searchCenter = _mapCenter;
      _showSearchArea = false;
    });
  }

  void _setRadius(double km) {
    setState(() {
      _radiusKm = km;
      _showSearchArea = false;
    });
    final center = _searchCenter;
    if (center != null) _moveMap(center, _zoomForRadius(km));
  }

  void _showActivitiesSheet(List<ActivityPost> group) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  group.length == 1
                      ? 'Activity nearby'
                      : '${group.length} activities in this area',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Shaded circles show the approximate area. Other people's exact spots are private.",
                  style: TextStyle(fontSize: 12, color: SketchColors.inkFaint),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: group
                    .map(
                      (a) => ListTile(
                        leading: CategoryIcon(a.category.name, size: 24),
                        title: Text(
                          a.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_summaryLine(a)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(sheetContext).pop();
                          context.push('/activity/${a.id}');
                        },
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(themeModeProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final center = _searchCenter;
    final query = center == null
        ? null
        : (
            lat: center.latitude,
            lng: center.longitude,
            radiusKm: _radiusKm,
            categoryId: _categoryId,
          );
    final nearbyAsync = query == null
        ? null
        : ref.watch(nearbyActivitiesProvider(query));

    final List<ActivityPost> activities;
    if (nearbyAsync == null) {
      activities = _lastActivities;
    } else {
      activities = nearbyAsync.when(
        data: (data) {
          _lastActivities = data;
          return data;
        },
        loading: () => _lastActivities,
        error: (_, __) => const <ActivityPost>[],
      );
    }

    final isLoggedIn = ref
        .watch(authControllerProvider)
        .maybeWhen(data: (s) => s.isLoggedIn, orElse: () => false);
    final mine = isLoggedIn
        ? ref
              .watch(myActivitiesProvider)
              .maybeWhen(data: (d) => d, orElse: () => const <ActivityPost>[])
        : const <ActivityPost>[];
    final exactById = {for (final m in mine) m.id: m.location};
    ActivityLocation locationFor(ActivityPost a) =>
        exactById[a.id] ?? a.location;

    final groups = <String, List<ActivityPost>>{};
    for (final a in activities) {
      final loc = locationFor(a);
      groups.putIfAbsent('${loc.latitude},${loc.longitude}', () => []).add(a);
    }

    final markers = <Marker>[];
    final approximateAreas = <CircleMarker>[];
    for (final group in groups.values) {
      final loc = locationFor(group.first);
      final point = LatLng(loc.latitude, loc.longitude);
      if (!loc.isExact) {
        approximateAreas.add(
          CircleMarker(
            point: point,
            radius: approximateAreaRadiusMeters,
            useRadiusInMeter: true,
            color: SketchColors.ink.withValues(alpha: 0.08),
            borderColor: SketchColors.ink.withValues(alpha: 0.30),
            borderStrokeWidth: 1,
          ),
        );
      }
      markers.add(
        Marker(
          point: point,
          width: 44,
          height: 44,
          child: _ActivityMarker(
            group: group,
            onTap: () => _showActivitiesSheet(group),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _mapCenter,
                    initialZoom: _zoomForRadius(_radiusKm),
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: _onMapReady,
                    onPositionChanged: _onPositionChanged,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConfig.tileUrl,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                    ),
                    if (center != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: center,
                            radius: _radiusKm * 1000,
                            useRadiusInMeter: true,
                            color: SketchColors.ink.withValues(alpha: 0.05),
                            borderColor: SketchColors.ink.withValues(
                              alpha: 0.4,
                            ),
                            borderStrokeWidth: 1.5,
                          ),
                        ],
                      ),
                    CircleLayer(circles: approximateAreas),
                    if (_userLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _userLocation!,
                            width: 22,
                            height: 22,
                            child: Container(
                              decoration: BoxDecoration(
                                color: SketchColors.ink,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: SketchColors.paper,
                                  width: 3,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(markers: markers),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildSearchBar(),
                          const SizedBox(height: 8),
                          _buildChipsRow(
                            categoriesAsync.when(
                              data: (c) => c,
                              loading: () => const [],
                              error: (_, __) => const [],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showSearchArea)
                  Positioned(
                    bottom: 44,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FilledButton.icon(
                        onPressed: _searchThisArea,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Search this area'),
                      ),
                    ),
                  ),
                Positioned(
                  right: 12,
                  bottom: 44,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    backgroundColor: SketchColors.paper,
                    foregroundColor: SketchColors.ink,
                    onPressed: _recenterOnMe,
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          _buildResultsStrip(nearbyAsync, activities),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 3,
      color: SketchColors.paper,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: _pickPlaceToExplore,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const SketchIcon('search', size: 20),
              const SizedBox(width: 10),
              Text(
                'Search a place or area...',
                style: TextStyle(color: SketchColors.inkFaint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChipsRow(List categories) {
    // Selection is shown with a heavier border + light tint, never a
    // solid dark fill -- the icons are drawn in solid dark ink, so a
    // dark selected background would make them disappear.
    Widget chip(
      String label,
      bool selected,
      VoidCallback onTap, {
      String? icon,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: icon == null ? null : SketchIcon(icon, size: 15),
          label: Text(label),
          selected: selected,
          showCheckmark: false,
          backgroundColor: SketchColors.paper,
          selectedColor: SketchColors.paperFleck,
          side: BorderSide(
            color: SketchColors.ink,
            width: selected ? 1.6 : 1.0,
          ),
          labelStyle: TextStyle(
            color: SketchColors.ink,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          onSelected: (_) => onTap(),
        ),
      );
    }

    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          PopupMenuButton<double>(
            initialValue: _radiusKm,
            onSelected: _setRadius,
            itemBuilder: (_) => _radiusOptions
                .map(
                  (r) => PopupMenuItem(
                    value: r,
                    child: Text('${r.toStringAsFixed(0)} km'),
                  ),
                )
                .toList(),
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.adjust, size: 16),
                label: Text('${_radiusKm.toStringAsFixed(0)} km'),
                backgroundColor: SketchColors.paper,
                side: BorderSide(color: SketchColors.ink),
              ),
            ),
          ),
          chip(
            'All',
            _categoryId == null,
            () => setState(() => _categoryId = null),
          ),
          for (final c in categories)
            chip(
              c.name,
              _categoryId == c.id,
              () => setState(() => _categoryId = c.id),
              icon: sketchAssetForCategory(c.name),
            ),
        ],
      ),
    );
  }

  Widget _buildResultsStrip(
    AsyncValue<List<ActivityPost>>? nearbyAsync,
    List<ActivityPost> activities,
  ) {
    Widget content;
    if (nearbyAsync == null || (nearbyAsync.isLoading && activities.isEmpty)) {
      content = const Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 18,
              width: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Finding activities...'),
          ],
        ),
      );
    } else if (nearbyAsync.hasError) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Couldn't load activities."),
            TextButton(
              onPressed: () => ref.invalidate(nearbyActivitiesProvider),
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    } else if (activities.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Center(
          child: Text(
            'No open activities within ${_radiusKm.toStringAsFixed(0)} km. Try a wider radius or search another area.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SketchColors.inkFaint),
          ),
        ),
      );
    } else {
      content = ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) => _MiniActivityCard(
          activity: activities[i],
          onTap: () => context.push('/activity/${activities[i].id}'),
        ),
      );
    }

    return SizedBox(
      height: 132,
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: content,
      ),
    );
  }
}

String _summaryLine(ActivityPost a) {
  final start = a.scheduledStart;
  final when =
      '${start.day}/${start.month} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
  final distance = a.distanceKm != null
      ? '${a.distanceKm!.toStringAsFixed(1)} km · '
      : '';
  return '$distance$when · ${a.totalSpotsNeeded} spots';
}

class _ActivityMarker extends StatelessWidget {
  final List<ActivityPost> group;
  final VoidCallback onTap;
  const _ActivityMarker({required this.group, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: SketchColors.paper,
              shape: BoxShape.circle,
              border: Border.all(color: SketchColors.ink, width: 1.6),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 5),
              ],
            ),
            child: Center(
              child: group.length == 1
                  ? CategoryIcon(group.first.category.name, size: 22)
                  : const SketchAllGlyph(size: 20),
            ),
          ),
          if (group.length > 1)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: SketchColors.paper,
                  shape: BoxShape.circle,
                  border: Border.all(color: SketchColors.ink, width: 1.2),
                ),
                child: Text(
                  '${group.length}',
                  style: TextStyle(
                    color: SketchColors.ink,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniActivityCard extends StatelessWidget {
  final ActivityPost activity;
  final VoidCallback onTap;
  const _MiniActivityCard({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        margin: EdgeInsets.zero,
        color: SketchColors.paper,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: SketchColors.ink, width: 1.2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: SketchColors.paperFleck.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: CategoryIcon(activity.category.name, size: 26),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _summaryLine(activity),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
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
