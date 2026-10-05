import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_error.dart';
import '../../../shared/models/activity_location.dart';
import '../../places/domain/place_result.dart';
import '../../places/presentation/location_picker_screen.dart';
import '../data/activities_providers.dart';
import '../domain/activity_post.dart';
import '../domain/update_activity_input.dart';
import '../../groups/data/groups_providers.dart';

class EditActivityScreen extends ConsumerStatefulWidget {
  final ActivityPost activity;
  final String? groupId;

  /// Best-known location. Only safe to resend to the server when
  /// `isExact` is true; a rounded one would degrade the stored point.
  final ActivityLocation location;

  const EditActivityScreen({
    super.key,
    required this.activity,
    required this.location,
    this.groupId,
  });

  @override
  ConsumerState<EditActivityScreen> createState() => _EditActivityScreenState();
}

class _EditActivityScreenState extends ConsumerState<EditActivityScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _venueController;
  late final TextEditingController _addressController;
  late double _lat;
  late double _lng;
  bool _pinMoved = false;
  bool _isSaving = false;
  late bool _costSharingEnabled;

  bool get _canEditLocation => widget.location.isExact;

  bool get _locationChanged =>
      _pinMoved ||
      _venueController.text.trim() != (widget.location.venueName ?? '') ||
      _addressController.text.trim() != (widget.location.addressText ?? '');

  @override
  void initState() {
    super.initState();
    final a = widget.activity;
    _costSharingEnabled = a.costSharingEnabled;
    _titleController = TextEditingController(text: a.title);
    _descriptionController = TextEditingController(text: a.description ?? '');
    _venueController = TextEditingController(
      text: widget.location.venueName ?? '',
    );
    _addressController = TextEditingController(
      text: widget.location.addressText ?? '',
    );
    _lat = widget.location.latitude;
    _lng = widget.location.longitude;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<PlaceResult>(
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(
              initial: PlaceResult(
                name: _venueController.text.trim().isEmpty
                    ? null
                    : _venueController.text.trim(),
                address: _addressController.text.trim().isEmpty
                    ? null
                    : _addressController.text.trim(),
                latitude: _lat,
                longitude: _lng,
              ),
            ),
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _lat = result.latitude;
      _lng = result.longitude;
      _pinMoved = true;
      _venueController.text = result.name ?? '';
      _addressController.text = result.address ?? '';
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Location is all-or-nothing in the API, and only sent when the
      // person actually changed it AND we hold the exact coordinates.
      final sendLocation = _canEditLocation && _locationChanged;
      final input = UpdateActivityInput(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        costSharingEnabled:
            _costSharingEnabled == widget.activity.costSharingEnabled
            ? null
            : _costSharingEnabled,
        location: sendLocation
            ? (
                latitude: _lat,
                longitude: _lng,
                addressText: _addressController.text.trim(),
                venueName: _venueController.text.trim(),
              )
            : null,
      );
      await ref
          .read(activitiesRepositoryProvider)
          .updateActivity(widget.activity.id, input);
      ref.invalidate(activityDetailProvider(widget.activity.id));
      ref.invalidate(myActivitiesProvider);
      ref.invalidate(activityFeedProvider(null));
      ref.invalidate(nearbyActivitiesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activity updated.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final expensesAsync = widget.groupId == null
        ? null
        : ref.watch(
            groupExpensesProvider((
              groupId: widget.groupId!,
              page: 1,
              pageSize: 1,
            )),
          );
    final hasExpenses = expensesAsync?.maybeWhen(
      data: (expenses) => expenses.count > 0,
      orElse: () => false,
    );
    final canDisableCostSharing =
        !_costSharingEnabled ||
        (widget.groupId != null &&
            expensesAsync?.hasValue == true &&
            hasExpenses == false);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Activity')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Enable shared costs'),
            subtitle: Text(
              _costSharingEnabled && hasExpenses == true
                  ? 'Shared expenses already exist, so cost sharing cannot be disabled.'
                  : _costSharingEnabled && widget.groupId == null
                  ? 'Cost sharing cannot be disabled unless the group expenses can be checked.'
                  : _costSharingEnabled && expensesAsync?.hasError == true
                  ? 'Could not verify expenses. Retry before disabling cost sharing.'
                  : _costSharingEnabled &&
                        expensesAsync != null &&
                        !expensesAsync.hasValue
                  ? 'Checking existing expenses before allowing cost sharing to be disabled.'
                  : 'Let group members record and split activity expenses.',
            ),
            value: _costSharingEnabled,
            secondary: expensesAsync?.hasError == true
                ? IconButton(
                    tooltip: 'Retry loading expenses',
                    onPressed: () => ref.invalidate(groupExpensesProvider),
                    icon: const Icon(Icons.refresh),
                  )
                : null,
            onChanged: canDisableCostSharing
                ? (enabled) =>
                      setState(() => _costSharingEnabled = enabled)
                : null,
          ),
          const SizedBox(height: 20),
          Text('Location', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _canEditLocation ? _pickOnMap : null,
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Location on map',
                enabled: _canEditLocation,
                prefixIcon: const Icon(Icons.place_outlined),
                suffixIcon: const Icon(Icons.map_outlined),
              ),
              child: Text(
                _canEditLocation
                    ? '${_lat.toStringAsFixed(5)}, ${_lng.toStringAsFixed(5)}'
                    : 'Unavailable right now',
              ),
            ),
          ),
          if (!_canEditLocation)
            const Padding(
              padding: EdgeInsets.only(top: 6, left: 4),
              child: Text(
                "Your exact location hasn't loaded yet, so it can't be edited safely. "
                'Go back, wait a moment, and try again. Title and description still save.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _venueController,
            enabled: _canEditLocation,
            decoration: const InputDecoration(labelText: 'Venue name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _addressController,
            enabled: _canEditLocation,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
