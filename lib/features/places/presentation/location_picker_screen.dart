import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/config/map_config.dart';
import '../../../core/theme/app_colors.dart';
import '../data/places_providers.dart';
import '../domain/place_result.dart';
import '../../../core/widgets/sketch_icon.dart';

/// Pops with a PlaceResult (the pin's exact coordinates + best-known
/// name/address), or null if the person backs out.
class LocationPickerScreen extends ConsumerStatefulWidget {
  final PlaceResult? initial;
  final double initialZoom;
  final String confirmLabel;

  const LocationPickerScreen({
    super.key,
    this.initial,
    this.initialZoom = 16,
    this.confirmLabel = 'Use this location',
  });

  @override
  ConsumerState<LocationPickerScreen> createState() =>
      _LocationPickerScreenState();
}

class _LocationPickerScreenState extends ConsumerState<LocationPickerScreen> {
  final _mapController = MapController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  late LatLng _center;
  PlaceResult? _place;
  bool _isResolving = false;
  bool _mapReady = false;
  ({LatLng point, double zoom})? _pendingMove;

  Timer? _resolveDebounce;
  int _resolveToken = 0;

  Timer? _searchDebounce;
  int _searchToken = 0;
  List<PlaceResult> _results = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _center = initial != null
        ? LatLng(initial.latitude, initial.longitude)
        : MapConfig.fallbackCenter;
    _place = initial;
    final needsLookup =
        initial == null || (initial.name == null && initial.address == null);
    _isResolving = needsLookup;

    if (initial == null) {
      _goToMyLocation(silent: true);
    } else if (needsLookup) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _resolvePlace());
    }
  }

  @override
  void dispose() {
    _resolveDebounce?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ---- map movement -------------------------------------------------

  void _onMapReady() {
    _mapReady = true;
    final pending = _pendingMove;
    if (pending != null) {
      _mapController.move(pending.point, pending.zoom);
      _pendingMove = null;
    }
  }

  void _moveTo(LatLng point, double zoom) {
    setState(() => _center = point);
    if (_mapReady) {
      _mapController.move(point, zoom);
    } else {
      _pendingMove = (point: point, zoom: zoom);
    }
  }

  /// Only *gesture* moves (dragging) trigger a fresh reverse lookup.
  /// Programmatic moves (search pick, my-location) set the label
  /// themselves -- otherwise reverse geocoding would overwrite a good
  /// shop name from search with whatever building is nearest.
  void _onPositionChanged(MapCamera camera, bool hasGesture) {
    _center = camera.center;
    if (!hasGesture) return;
    _resolveDebounce?.cancel();
    if (!_isResolving) setState(() => _isResolving = true);
    _resolveDebounce = Timer(const Duration(milliseconds: 600), _resolvePlace);
  }

  void _onMapTap(LatLng point) {
    _searchFocus.unfocus();
    _resolveDebounce?.cancel();
    _moveTo(point, _mapReady ? _mapController.camera.zoom : widget.initialZoom);
    _resolvePlace();
  }

  Future<void> _goToMyLocation({bool silent = false}) async {
    final location = await ref
        .read(locationServiceProvider)
        .getCurrentLocation();
    if (!mounted) return;
    if (location == null) {
      if (!silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't get your location. Check location permission.",
            ),
          ),
        );
      }
      _resolvePlace(); // still label the fallback center
      return;
    }
    _resolveDebounce?.cancel();
    _moveTo(location, 17);
    _resolvePlace();
  }

  Future<void> _resolvePlace() async {
    final target = _center;
    final token = ++_resolveToken;
    if (mounted) setState(() => _isResolving = true);
    try {
      final result = await ref.read(geocodingServiceProvider).reverse(target);
      if (!mounted || token != _resolveToken) return;
      setState(() {
        _place = result;
        _isResolving = false;
      });
    } catch (_) {
      if (!mounted || token != _resolveToken) return;
      setState(() {
        _place = null;
        _isResolving = false;
      });
    }
  }

  // ---- search -------------------------------------------------------

  void _onSearchChanged(String value) {
    setState(() {}); // refreshes the clear button
    _searchDebounce?.cancel();
    final query = value.trim();
    if (query.length < 3) {
      _searchToken++;
      setState(() {
        _results = [];
        _isSearching = false;
        _searchError = null;
      });
      return;
    }
    // Debounced to stay within the free geocoder's fair-use limits.
    _searchDebounce = Timer(
      const Duration(milliseconds: 450),
      () => _runSearch(query),
    );
  }

  Future<void> _runSearch(String query) async {
    final token = ++_searchToken;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final results = await ref
          .read(geocodingServiceProvider)
          .search(query, near: _center);
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = results;
        _isSearching = false;
        _searchError = results.isEmpty ? 'No places found for "$query".' : null;
      });
    } catch (_) {
      if (!mounted || token != _searchToken) return;
      setState(() {
        _results = [];
        _isSearching = false;
        _searchError =
            'Search is unavailable right now. You can still move the map.';
      });
    }
  }

  void _selectResult(PlaceResult result) {
    _searchDebounce?.cancel();
    _resolveDebounce?.cancel();
    _resolveToken++; // discard any in-flight reverse lookup
    _searchToken++;
    _searchFocus.unfocus();
    _searchController.text = result.title;
    setState(() {
      _results = [];
      _searchError = null;
      _isSearching = false;
      _isResolving = false;
      _place = result;
    });
    _moveTo(LatLng(result.latitude, result.longitude), 17);
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchToken++;
    _searchController.clear();
    setState(() {
      _results = [];
      _isSearching = false;
      _searchError = null;
    });
  }

  void _confirm() {
    final place = _isResolving ? null : _place; // don't return a stale name
    Navigator.of(context).pop(
      PlaceResult(
        name: place?.name,
        address: place?.address,
        latitude: _center.latitude,
        longitude: _center.longitude,
      ),
    );
  }

  // ---- UI -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final showSearchPanel =
        _isSearching || _searchError != null || _results.isNotEmpty;

    return Scaffold(
      resizeToAvoidBottomInset: false, // keyboard must not resize the map
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: widget.initial != null
                        ? widget.initialZoom
                        : 15,
                    minZoom: 3,
                    maxZoom: 19,
                    onMapReady: _onMapReady,
                    onPositionChanged: _onPositionChanged,
                    onTap: (tapPosition, point) => _onMapTap(point),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: MapConfig.tileUrl,
                      userAgentPackageName: MapConfig.userAgentPackageName,
                    ),
                    const SimpleAttributionWidget(
                      source: Text('OpenStreetMap contributors'),
                    ),
                  ],
                ),
                // Fixed pin: its tip sits exactly on the map center.
                const IgnorePointer(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 40),
                      child: Icon(
                        Icons.location_on,
                        size: 40,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
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
                          if (showSearchPanel) _buildSearchPanel(),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  bottom: 44,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: () => _goToMyLocation(),
                    child: const Icon(Icons.my_location),
                  ),
                ),
              ],
            ),
          ),
          _buildBottomCard(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Material(
      elevation: 3,
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SketchIcon('search', size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search places, shops, areas...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
              ),
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(icon: const Icon(Icons.close), onPressed: _clearSearch),
        ],
      ),
    );
  }

  Widget _buildSearchPanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        elevation: 3,
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 280),
          child: _isSearching
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: LinearProgressIndicator(),
                )
              : _results.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _searchError ?? '',
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final r = _results[i];
                    return ListTile(
                      dense: true,
                      leading: const SketchIcon('pin', size: 20),
                      title: Text(
                        r.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: r.subtitle.isEmpty
                          ? null
                          : Text(
                              r.subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () => _selectResult(r),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildBottomCard() {
    final title = _isResolving
        ? 'Finding place...'
        : (_place?.title ?? 'Dropped pin');
    final subtitle = _isResolving
        ? ''
        : (_place == null
              ? 'No place name found here. You can still use this spot.'
              : _place!.subtitle);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SketchIcon('pin', size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle.isNotEmpty)
                        Text(
                          subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_center.latitude.toStringAsFixed(5)}, ${_center.longitude.toStringAsFixed(5)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _confirm,
              child: Text(widget.confirmLabel),
            ),
          ],
        ),
      ),
    );
  }
}
