import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/domain/age_eligibility.dart';
import '../../auth/domain/app_user.dart';
import '../../auth/domain/social_profile.dart';
import '../../auth/presentation/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  final AppUser user;
  const EditProfileScreen({super.key, required this.user});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  static const _platforms = <({String id, String label, IconData icon})>[
    (id: 'instagram', label: 'Instagram', icon: Icons.camera_alt_outlined),
    (id: 'facebook', label: 'Facebook', icon: Icons.facebook),
    (id: 'tiktok', label: 'TikTok', icon: Icons.music_note),
    (id: 'x', label: 'X', icon: Icons.close),
    (id: 'linkedin', label: 'LinkedIn', icon: Icons.work_outline),
    (id: 'youtube', label: 'YouTube', icon: Icons.smart_display_outlined),
    (id: 'snapchat', label: 'Snapchat', icon: Icons.photo_camera_outlined),
  ];
  static const _customPlatform = 'custom';

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  late final List<_SocialProfileDraft> _socialProfiles;
  DateTime? _dateOfBirth;
  Uint8List? _pickedBytes;
  String? _pickedFilename;
  bool _isSaving = false;

  DateTime get _latestEligibleDob => latestEligibleDateOfBirth();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.fullName);
    _emailController = TextEditingController(text: widget.user.email ?? '');
    _dateOfBirth = widget.user.dateOfBirth;
    _socialProfiles = widget.user.socialProfiles
        .map(_SocialProfileDraft.fromProfile)
        .toList();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    for (final profile in _socialProfiles) {
      profile.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedBytes = bytes;
      _pickedFilename = picked.name;
    });
  }

  Future<void> _pickDateOfBirth() async {
    final latestDob = _latestEligibleDob;
    final initial =
        _dateOfBirth != null &&
            !_dateOfBirth!.isAfter(latestDob) &&
            _dateOfBirth!.year >= 1900
        ? _dateOfBirth!
        : DateTime(latestDob.year - 7, latestDob.month, latestDob.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: latestDob,
      helpText: 'Date of birth (you must be 18 or older)',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _addSocialProfile() {
    setState(() => _socialProfiles.add(_SocialProfileDraft()));
  }

  Future<void> _choosePlatform(_SocialProfileDraft draft) async {
    final theme = Theme.of(context);
    final selection = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: SketchColors.paper,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              child: Text(
                'Choose a social platform',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            for (final platform in _platforms)
              _platformOptionTile(
                sheetContext,
                platform.id,
                platform.label,
                platform.icon,
                draft,
              ),
            _platformOptionTile(
              sheetContext,
              _customPlatform,
              'Other platform',
              Icons.add,
              draft,
            ),
          ],
        ),
      ),
    );
    if (selection == null || !mounted) return;
    setState(() {
      if (selection == _customPlatform) {
        if (!draft.isCustom) draft.platformController.clear();
        draft.isCustom = true;
        draft.platform = '';
      } else {
        draft.isCustom = false;
        draft.platform = selection;
      }
    });
  }

  Widget _platformOptionTile(
    BuildContext sheetContext,
    String id,
    String label,
    IconData icon,
    _SocialProfileDraft draft,
  ) {
    final isSelected = id == _customPlatform
        ? draft.isCustom
        : !draft.isCustom && draft.platform.toLowerCase() == id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: SketchBox(
        seed: id.hashCode,
        radius: 14,
        strokeWidth: isSelected ? 2 : 1.4,
        fill: isSelected
            ? SketchColors.paperFleck.withValues(alpha: 0.25)
            : null,
        padding: EdgeInsets.zero,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => Navigator.of(sheetContext).pop(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Icon(icon, color: SketchColors.ink),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: SketchColors.ink),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, String>> _buildSocialProfilePayload() {
    final profiles = <Map<String, String>>[];
    final platforms = <String>{};
    for (final draft in _socialProfiles) {
      final platform = draft.selectedPlatform.trim();
      final username = draft.usernameController.text.trim();
      final profileUrl = draft.urlController.text.trim();
      if (platform.isEmpty && username.isEmpty && profileUrl.isEmpty) continue;

      final platformKey = platform.toLowerCase();
      if (platform.isEmpty) {
        throw const FormatException('Choose or enter a social platform.');
      }
      if (username.isEmpty && profileUrl.isEmpty) {
        throw const FormatException(
          'Enter a username or profile URL for each social profile.',
        );
      }
      if (!platforms.add(platformKey)) {
        throw FormatException('Only one profile per platform is allowed.');
      }
      if (profileUrl.isNotEmpty) {
        final uri = Uri.tryParse(profileUrl);
        if (uri == null ||
            !uri.hasScheme ||
            !uri.hasAuthority ||
            (uri.scheme != 'https' && uri.scheme != 'http')) {
          throw const FormatException(
            'Enter a valid social profile URL starting with http:// or https://.',
          );
        }
      }
      profiles.add({
        'platform': platform,
        if (username.isNotEmpty) 'username': username,
        if (profileUrl.isNotEmpty) 'profile_url': profileUrl,
      });
    }
    return profiles;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final dob = _dateOfBirth;
    if (dob == null) {
      _showError('Pick your date of birth.');
      return;
    }
    if (!isAtLeast18(dob)) {
      _showError('You must be at least 18 years old to use this app.');
      return;
    }

    late final List<Map<String, String>> socialProfiles;
    try {
      socialProfiles = _buildSocialProfilePayload();
    } on FormatException catch (error) {
      _showError(error.message);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfileText({
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'date_of_birth': _formatDate(dob),
        if (socialProfiles.isNotEmpty) 'social_profiles': socialProfiles,
      });
      if (_pickedBytes != null) {
        await ref
            .read(authControllerProvider.notifier)
            .updateProfileWithAvatar(
              avatarBytes: _pickedBytes!,
              avatarFilename: _pickedFilename!,
            );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (_pickedBytes != null) {
      avatarImage = MemoryImage(_pickedBytes!);
    } else if (widget.user.avatar != null) {
      avatarImage = NetworkImage(widget.user.avatar!);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            SketchBox(
              seed: widget.user.id.hashCode + 40,
              radius: 22,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SketchBox(
                        seed: widget.user.id.hashCode + 41,
                        radius: 58,
                        width: 112,
                        height: 112,
                        child: Center(
                          child: ClipOval(
                            child: SizedBox(
                              width: 94,
                              height: 94,
                              child: avatarImage != null
                                  ? Image(
                                      image: avatarImage,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => UserAvatar(
                                        avatarUrl: null,
                                        radius: 47,
                                      ),
                                    )
                                  : UserAvatar(
                                      avatarUrl: widget.user.avatar,
                                      radius: 47,
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: -4,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _pickImage,
                            customBorder: const CircleBorder(),
                            child: SketchBox(
                              seed: 42,
                              radius: 20,
                              width: 38,
                              height: 38,
                              child: const Center(
                                child: Icon(
                                  Icons.camera_alt_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.user.fullName.isEmpty
                        ? 'Update your profile photo'
                        : widget.user.fullName,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: 180,
                    child: SketchButton(
                      label: _pickedBytes == null
                          ? 'Change photo'
                          : 'Choose another photo',
                      icon: const Icon(Icons.photo_library_outlined),
                      onPressed: _pickImage,
                      seed: 43,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            _EditSectionHeading(
              title: 'Personal information',
              icon: const SketchIcon('profile', size: 23),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 44,
              radius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your full name.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Enter your email.';
                      if (!RegExp(
                        r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                      ).hasMatch(email)) {
                        return 'Enter a valid email address.';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _EditSectionHeading(
              title: 'Date of birth',
              icon: const SketchIcon('calendar', size: 23),
            ),
            const SizedBox(height: 10),
            SketchBox(
              seed: 45,
              radius: 16,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SketchButton(
                    label: _dateOfBirth == null
                        ? 'Choose your date of birth'
                        : _formatDate(_dateOfBirth!),
                    icon: const Icon(Icons.calendar_today_outlined),
                    onPressed: _pickDateOfBirth,
                    seed: 46,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You must be at least 18 years old.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: SketchColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: _EditSectionHeading(
                    title: 'Social profiles',
                    icon: const SketchIcon('social_table', size: 24),
                  ),
                ),
                SizedBox(
                  width: 112,
                  child: SketchButton(
                    label: 'Add',
                    icon: const Icon(Icons.add),
                    onPressed: _addSocialProfile,
                    seed: 47,
                  ),
                ),
              ],
            ),
            if (_socialProfiles.isEmpty) ...[
              const SizedBox(height: 10),
              SketchBox(
                radius: 14,
                fill: null,
                padding: const EdgeInsets.all(14),
                child: const Text(
                  'Add a social profile to update your verification.',
                ),
              ),
            ],
            for (var index = 0; index < _socialProfiles.length; index++)
              _buildSocialProfileEditor(index),
            const SizedBox(height: 24),
            SketchButton(
              label: 'Save changes',
              icon: const Icon(Icons.check),
              filled: true,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _save,
              seed: 48,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialProfileEditor(int index) {
    final draft = _socialProfiles[index];
    final selectedPlatform = _platforms.where(
      (platform) => platform.id == draft.platform.toLowerCase(),
    );
    final selectedOption = selectedPlatform.isEmpty
        ? null
        : selectedPlatform.first;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SketchBox(
        seed: draft.selectedPlatform.hashCode + index,
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _choosePlatform(draft),
              child: SketchBox(
                seed: index + 50,
                radius: 12,
                fill: null,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 13,
                ),
                child: Row(
                  children: [
                    Icon(
                      draft.isCustom
                          ? Icons.add
                          : selectedOption?.icon ?? Icons.public,
                      size: 20,
                      color: SketchColors.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Platform',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: SketchColors.inkFaint),
                          ),
                          Text(
                            draft.isCustom
                                ? (draft.platformController.text.isEmpty
                                      ? 'Other platform'
                                      : draft.platformController.text)
                                : selectedOption?.label ?? 'Select a platform',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.expand_more),
                  ],
                ),
              ),
            ),
            if (draft.isCustom) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: draft.platformController,
                decoration: const InputDecoration(
                  labelText: 'Platform name',
                  hintText: 'e.g. Threads',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                onChanged: (value) {
                  setState(() => draft.platform = value.trim());
                },
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: draft.usernameController,
              decoration: const InputDecoration(
                labelText: 'Username (optional if URL is provided)',
                prefixIcon: Icon(Icons.alternate_email),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: draft.urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Profile URL (optional)',
                hintText: 'https://',
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class _EditSectionHeading extends StatelessWidget {
  final String title;
  final Widget icon;

  const _EditSectionHeading({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SocialProfileDraft {
  _SocialProfileDraft({String? platform})
    : platform = platform ?? '',
      isCustom =
          platform != null &&
          !_EditProfileScreenState._platforms.any(
            (item) => item.id == platform.toLowerCase(),
          ),
      platformController = TextEditingController(
        text:
            platform != null &&
                !_EditProfileScreenState._platforms.any(
                  (item) => item.id == platform.toLowerCase(),
                )
            ? platform
            : '',
      );

  factory _SocialProfileDraft.fromProfile(SocialProfile profile) {
    final draft = _SocialProfileDraft(platform: profile.platform);
    draft.usernameController.text = profile.username ?? '';
    draft.urlController.text = profile.profileUrl ?? '';
    return draft;
  }

  String platform;
  bool isCustom;
  final TextEditingController platformController;
  final usernameController = TextEditingController();
  final urlController = TextEditingController();

  String get selectedPlatform => isCustom ? platformController.text : platform;

  void dispose() {
    platformController.dispose();
    usernameController.dispose();
    urlController.dispose();
  }
}
