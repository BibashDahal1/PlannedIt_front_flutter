import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../places/domain/place_result.dart';
import '../../places/presentation/location_picker_screen.dart';
import '../data/activities_providers.dart';
import '../domain/create_activity_input.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Post Activity')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SketchBox(
              seed: 70,
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const SketchIcon('plus', size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create an activity',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          'Share your plan and find people to join.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: SketchColors.inkFaint),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PostSectionHeading(
              title: 'Activity details',
              icon: const SketchIcon('calendar', size: 24),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 71,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  FormField<int>(
                    validator: (_) =>
                        _selectedCategoryId == null ? 'Pick a category' : null,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    builder: (field) => categoriesAsync.when(
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: SketchColors.ink,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      error: (e, _) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Could not load categories: ${extractApiErrorMessage(e)}',
                            style: TextStyle(color: SketchColors.danger),
                          ),
                          const SizedBox(height: 8),
                          SketchButton(
                            label: 'Retry categories',
                            icon: const Icon(Icons.refresh),
                            onPressed: () => ref.invalidate(categoriesProvider),
                          ),
                        ],
                      ),
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
                              backgroundColor: SketchColors.paper,
                              showDragHandle: true,
                              builder: (sheetContext) => SafeArea(
                                child: ListView(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    4,
                                    16,
                                    20,
                                  ),
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        4,
                                        4,
                                        4,
                                        12,
                                      ),
                                      child: Text(
                                        'Choose a category',
                                        style: Theme.of(sheetContext)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    for (final category in categories)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: SketchBox(
                                          seed: category.id,
                                          radius: 14,
                                          fill:
                                              category.id == _selectedCategoryId
                                              ? SketchColors.paperFleck
                                                    .withValues(alpha: 0.25)
                                              : null,
                                          padding: EdgeInsets.zero,
                                          child: Material(
                                            color: Colors.transparent,
                                            child: InkWell(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              onTap: () => Navigator.of(
                                                sheetContext,
                                              ).pop(category.id),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
                                                child: Row(
                                                  children: [
                                                    CategoryIcon(
                                                      category.name,
                                                      iconKey: category.iconKey,
                                                      size: 26,
                                                    ),
                                                    const SizedBox(width: 12),
                                                    Expanded(
                                                      child: Text(
                                                        category.name,
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                    ),
                                                    if (category.id ==
                                                        _selectedCategoryId)
                                                      Icon(
                                                        Icons.check_circle,
                                                        color: SketchColors.ink,
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                            if (pickedId != null) {
                              setState(() => _selectedCategoryId = pickedId);
                              field.didChange(pickedId);
                            }
                          },
                          child: SketchBox(
                            seed: 72,
                            radius: 14,
                            fill: null,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 13,
                            ),
                            child: Row(
                              children: [
                                if (selected == null)
                                  Icon(
                                    Icons.category_outlined,
                                    color: SketchColors.inkFaint,
                                  )
                                else
                                  CategoryIcon(
                                    selected.name,
                                    iconKey: selected.iconKey,
                                    size: 26,
                                  ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Category',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: SketchColors.inkFaint,
                                            ),
                                      ),
                                      Text(
                                        selected?.name ?? 'Select a category',
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
                        );
                      },
                    ),
                  ),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      prefixIcon: Icon(Icons.edit_outlined),
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PostSectionHeading(
              title: 'Location',
              icon: const SketchIcon('pin', size: 24),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 73,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  FormField<PlaceResult>(
                    validator: (_) =>
                        _place == null ? 'Choose a location on the map' : null,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    builder: (field) => Column(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _pickLocation(field),
                          child: SketchBox(
                            seed: 74,
                            radius: 14,
                            fill: null,
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                const SketchIcon('pin', size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Choose on map',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: SketchColors.inkFaint,
                                            ),
                                      ),
                                      Text(
                                        _place?.title ??
                                            'Tap to choose a location',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (_place?.subtitle.isNotEmpty == true)
                                        Text(
                                          _place!.subtitle,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: SketchColors.inkFaint,
                                              ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.map_outlined),
                              ],
                            ),
                          ),
                        ),
                        if (field.errorText != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4, left: 8),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                  color: SketchColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SketchBox(
              radius: 12,
              fill: null,
              padding: const EdgeInsets.all(10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 18,
                    color: SketchColors.inkFaint,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Others only see an approximate area until they're accepted.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: SketchColors.inkFaint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 75,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  TextFormField(
                    controller: _venueController,
                    decoration: const InputDecoration(
                      labelText: 'Venue name (optional)',
                      prefixIcon: Icon(Icons.storefront_outlined),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address (optional)',
                      prefixIcon: Icon(Icons.signpost_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PostSectionHeading(
              title: 'Date & time',
              icon: const SketchIcon('calendar', size: 24),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 76,
              radius: 18,
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  SketchButton(
                    label: _startDateTime == null
                        ? 'Set start time'
                        : 'Starts ${_formatDateTime(_startDateTime!)}',
                    icon: const Icon(Icons.play_arrow),
                    onPressed: () => _pickDateTime(isStart: true),
                    seed: 77,
                  ),
                  const SizedBox(height: 10),
                  SketchButton(
                    label: _endDateTime == null
                        ? 'Set end time'
                        : 'Ends ${_formatDateTime(_endDateTime!)}',
                    icon: const Icon(Icons.flag_outlined),
                    onPressed: () => _pickDateTime(isStart: false),
                    seed: 78,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PostSectionHeading(
              title: 'Group settings',
              icon: const SketchIcon('people', size: 24),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 79,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _spotsController,
                          decoration: const InputDecoration(
                            labelText: 'People needed',
                            prefixIcon: Icon(Icons.people_outline),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (v) =>
                              int.tryParse(v?.trim() ?? '') == null
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
                            prefixIcon: Icon(Icons.groups_outlined),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: const SketchIcon('people', size: 26),
                    title: const Text(
                      'Enable shared costs',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Let group members add and split expenses.',
                      style: TextStyle(color: SketchColors.inkFaint),
                    ),
                    value: _costSharingEnabled,
                    onChanged: (enabled) =>
                        setState(() => _costSharingEnabled = enabled),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _PostSectionHeading(
              title: 'Visibility & verification',
              icon: const SketchIcon('profile', size: 24),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 80,
              radius: 18,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SketchChoiceSelector(
                    title: 'Visibility',
                    subtitle: 'Who can discover this activity?',
                    icon: Icons.visibility_outlined,
                    value: _visibility,
                    onChanged: (value) =>
                        setState(() => _visibility = value),
                    options: const [
                      (
                        value: 'public',
                        label: 'Public',
                        description: 'Anyone can find and request to join.',
                      ),
                      (
                        value: 'nearby_only',
                        label: 'Nearby only',
                        description: 'Shown to people in your nearby area.',
                      ),
                      (
                        value: 'invite_only',
                        label: 'Invite only',
                        description: 'Only people you invite can join.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _SketchChoiceSelector(
                    title: 'Minimum verification',
                    subtitle: 'Who is eligible to request to join?',
                    icon: Icons.verified_user_outlined,
                    value: _minTier,
                    onChanged: (value) => setState(() => _minTier = value),
                    options: const [
                      (
                        value: 'basic',
                        label: 'Basic',
                        description: 'Basic account verification.',
                      ),
                      (
                        value: 'social_verified',
                        label: 'Social verified',
                        description: 'Requires a verified social profile.',
                      ),
                      (
                        value: 'fully_verified',
                        label: 'Fully verified',
                        description: 'Requires full account verification.',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SketchButton(
              label: 'Publish activity',
              icon: const Icon(Icons.publish),
              filled: true,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
              seed: 81,
            ),
          ],
        ),
      ),
    );
  }
}

class _PostSectionHeading extends StatelessWidget {
  final String title;
  final Widget icon;

  const _PostSectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 9),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _SketchChoiceSelector extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String value;
  final ValueChanged<String> onChanged;
  final List<({String value, String label, String description})> options;

  const _SketchChoiceSelector({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: SketchColors.ink),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: SketchColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SketchColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final option = options[index];
              final selected = option.value == value;
              return SketchBox(
                seed: 82 + index,
                radius: 13,
                fill: selected
                    ? SketchColors.paperFleck.withValues(alpha: 0.42)
                    : null,
                padding: EdgeInsets.zero,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onChanged(option.value),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: SketchColors.ink,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  option.label,
                                  style: TextStyle(
                                    color: SketchColors.ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  option.description,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: SketchColors.inkFaint),
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
            },
          ),
        ],
      ],
    );
  }
}
