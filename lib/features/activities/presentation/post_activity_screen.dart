import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/app_colors.dart';
import '../../places/domain/place_result.dart';
import '../../places/presentation/location_picker_screen.dart';
import '../data/activities_providers.dart';
import '../domain/create_activity_input.dart';
import '../../../core/widgets/sketch_icon.dart';

class PostActivityScreen extends ConsumerStatefulWidget {
  const PostActivityScreen({super.key});

  @override
  ConsumerState<PostActivityScreen> createState() => _PostActivityScreenState();
}

class _PostActivityScreenState extends ConsumerState<PostActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  final _addressController = TextEditingController();
  final _spotsController = TextEditingController(text: '4');
  final _teamSizeController = TextEditingController();

  int? _selectedCategoryId;
  PlaceResult? _place;
  DateTime? _startDateTime;
  DateTime? _endDateTime;
  String _visibility = 'public';
  String _minTier = 'basic';
  bool _costSharingEnabled = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _addressController.dispose();
    _spotsController.dispose();
    _teamSizeController.dispose();
    super.dispose();
  }

  Future<void> _pickLocation(FormFieldState<PlaceResult> field) async {
    final result = await Navigator.of(context, rootNavigator: true)
        .push<PlaceResult>(
          MaterialPageRoute(
            builder: (_) => LocationPickerScreen(initial: _place),
          ),
        );
    if (result == null || !mounted) return;
    setState(() {
      _place = result;
      // Pre-fill from the pick; both stay editable.
      _venueController.text = result.name ?? '';
      _addressController.text = result.address ?? '';
    });
    field.didChange(result);
  }

  Future<void> _pickDateTime({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(hours: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;
    final combined = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() {
      if (isStart) {
        _startDateTime = combined;
      } else {
        _endDateTime = combined;
      }
    });
  }

  String _formatDateTime(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  void _resetForm() {
    _formKey.currentState?.reset();
    _titleController.clear();
    _descriptionController.clear();
    _venueController.clear();
    _addressController.clear();
    _spotsController.text = '4';
    _teamSizeController.clear();
    setState(() {
      _selectedCategoryId = null;
      _place = null;
      _startDateTime = null;
      _endDateTime = null;
      _visibility = 'public';
      _minTier = 'basic';
      _costSharingEnabled = false;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDateTime == null || _endDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set a start and end time.')),
      );
      return;
    }
    if (!_startDateTime!.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be in the future.')),
      );
      return;
    }
    if (!_endDateTime!.isAfter(_startDateTime!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after the start time.')),
      );
      return;
    }

    final place = _place!;
    final input = CreateActivityInput(
      categoryId: _selectedCategoryId!,
      latitude: place.latitude,
      longitude: place.longitude,
      addressText: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      venueName: _venueController.text.trim().isEmpty
          ? null
          : _venueController.text.trim(),
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
      totalSpotsNeeded: int.parse(_spotsController.text.trim()),
      teamSize: _teamSizeController.text.trim().isEmpty
          ? null
          : int.tryParse(_teamSizeController.text.trim()),
      scheduledStart: _startDateTime!,
      scheduledEnd: _endDateTime!,
      visibility: _visibility,
      minVerificationTier: _minTier,
      costSharingEnabled: _costSharingEnabled,
    );

    setState(() => _isSubmitting = true);
    try {
      final createdId = await ref
          .read(activitiesRepositoryProvider)
          .createActivity(input);
      if (!mounted) return;
      ref.invalidate(activityFeedProvider(null));
      ref.invalidate(nearbyActivitiesProvider);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Activity posted!')));
      _resetForm();
      context.push('/activity/$createdId');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    const hintStyle = TextStyle(color: AppColors.textSecondary);

    return Scaffold(
      appBar: AppBar(title: const Text('Post Activity')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            FormField<int>(
              validator: (_) =>
                  _selectedCategoryId == null ? 'Pick a category' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              builder: (field) => categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load categories: $e'),
                data: (categories) {
                  final matches = categories.where(
                    (c) => c.id == _selectedCategoryId,
                  );
                  final selected = matches.isEmpty ? null : matches.first;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final pickedId = await showModalBottomSheet<int>(
                        context: context,
                        builder: (sheetContext) => SafeArea(
                          child: ListView(
                            shrinkWrap: true,
                            children: categories
                                .map(
                                  (c) => ListTile(
                                    leading: CategoryIcon(c.name, size: 22),
                                    title: Text(c.name),
                                    selected: c.id == _selectedCategoryId,
                                    onTap: () =>
                                        Navigator.of(sheetContext).pop(c.id),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      );
                      if (pickedId != null) {
                        setState(() => _selectedCategoryId = pickedId);
                        field.didChange(pickedId);
                      }
                    },
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Category',
                        errorText: field.errorText,
                        suffixIcon: const Icon(Icons.arrow_drop_down),
                      ),
                      child: selected == null
                          ? const Text(
                              'Select a category',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          : Row(
                              children: [
                                CategoryIcon(selected.name, size: 20),
                                const SizedBox(width: 8),
                                Text(selected.name),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            FormField<PlaceResult>(
              validator: (_) =>
                  _place == null ? 'Choose a location on the map' : null,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              builder: (field) => InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pickLocation(field),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Pick on map',
                    errorText: field.errorText,
                    prefixIcon: const Icon(Icons.place_outlined),
                    suffixIcon: const Icon(Icons.map_outlined),
                  ),
                  child: _place == null
                      ? const Text('Tap to choose a location', style: hintStyle)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _place!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_place!.subtitle.isNotEmpty)
                              Text(
                                _place!.subtitle,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                          ],
                        ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                "Others only see an approximate area until they're accepted.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _venueController,
              decoration: const InputDecoration(
                labelText: 'Venue name (optional)',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Address (optional)',
              ),
            ),
            const SizedBox(height: 20),
            Text('Date & Time', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickDateTime(isStart: true),
              child: Text(
                _startDateTime == null
                    ? 'Set start time'
                    : _formatDateTime(_startDateTime!),
              ),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => _pickDateTime(isStart: false),
              child: Text(
                _endDateTime == null
                    ? 'Set end time'
                    : _formatDateTime(_endDateTime!),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _spotsController,
                    decoration: const InputDecoration(
                      labelText: 'People needed',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (v) => int.tryParse(v?.trim() ?? '') == null
                        ? 'Invalid'
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _teamSizeController,
                    decoration: const InputDecoration(
                      labelText: 'Team size (optional)',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable shared costs'),
              subtitle: const Text(
                'Off by default. Enable this to let group members add and split expenses.',
              ),
              value: _costSharingEnabled,
              onChanged: (enabled) =>
                  setState(() => _costSharingEnabled = enabled),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(labelText: 'Visibility'),
              items: const [
                DropdownMenuItem(value: 'public', child: Text('Public')),
                DropdownMenuItem(
                  value: 'nearby_only',
                  child: Text('Nearby only'),
                ),
                DropdownMenuItem(
                  value: 'invite_only',
                  child: Text('Invite only'),
                ),
              ],
              onChanged: (v) => setState(() => _visibility = v!),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _minTier,
              decoration: const InputDecoration(
                labelText: 'Min. verification tier',
              ),
              items: const [
                DropdownMenuItem(value: 'basic', child: Text('Basic')),
                DropdownMenuItem(
                  value: 'social_verified',
                  child: Text('Social Verified'),
                ),
                DropdownMenuItem(
                  value: 'fully_verified',
                  child: Text('Fully Verified'),
                ),
              ],
              onChanged: (v) => setState(() => _minTier = v!),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Publish'),
            ),
          ],
        ),
      ),
    );
  }
}
