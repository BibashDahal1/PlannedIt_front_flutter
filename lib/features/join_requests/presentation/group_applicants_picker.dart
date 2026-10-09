import 'package:flutter/material.dart';

import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_icon.dart';
import '../../../core/widgets/user_avatar.dart';
import '../data/group_applications.dart';

/// Host-side view of a group application. In pending requests the host ticks
/// which applicants to accept (capped by the spots left); once handled it
/// becomes a read-only list showing each applicant's outcome.
class GroupApplicantsPicker extends StatelessWidget {
  final GroupApplication application;

  /// Spots left on the activity, or null if unknown (server stays the judge).
  final int? spotsRemaining;
  final Set<String> selected;
  final bool readOnly;
  final ValueChanged<String> onToggle;

  const GroupApplicantsPicker({
    super.key,
    required this.application,
    required this.spotsRemaining,
    required this.selected,
    required this.onToggle,
    this.readOnly = false,
  });

  static String _label(String value) {
    if (value.isEmpty) return 'Not set';
    return value
        .split(RegExp(r'[_\s]+'))
        .where((p) => p.isNotEmpty)
        .map((p) => '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spots = spotsRemaining;
    final counter = spots == null
        ? '${selected.length} selected'
        : '${selected.length} / $spots';

    return SketchBox(
      seed: application.groupId.hashCode,
      radius: 16,
      fill: null,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SketchIcon('people', size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  application.groupName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!readOnly)
                SketchBox(
                  seed: application.groupId.hashCode + 1,
                  radius: 10,
                  fill: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  child: Text(
                    counter,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            readOnly
                ? '${application.applicants.length} applicants'
                : spots == null
                ? 'Choose who to accept.'
                : spots == 0
                ? 'No spots left on this activity.'
                : 'Choose who to accept (up to $spots).',
            style: theme.textTheme.bodySmall?.copyWith(
              color: SketchColors.inkFaint,
            ),
          ),
          const SizedBox(height: 10),
          for (final a in application.applicants)
            _ApplicantRow(
              applicant: a,
              checked: selected.contains(a.id),
              selectable: !readOnly && a.isPending,
              disabled:
                  !readOnly &&
                  a.isPending &&
                  spots != null &&
                  selected.length >= spots &&
                  !selected.contains(a.id),
              onTap: () => onToggle(a.id),
              statusLabel: readOnly || !a.isPending ? _label(a.status) : null,
            ),
        ],
      ),
    );
  }
}

class _ApplicantRow extends StatelessWidget {
  final GroupApplicant applicant;
  final bool checked;
  final bool selectable;
  final bool disabled;
  final VoidCallback onTap;
  final String? statusLabel;

  const _ApplicantRow({
    required this.applicant,
    required this.checked,
    required this.selectable,
    required this.disabled,
    required this.onTap,
    required this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final seed = applicant.id.hashCode;
    final trust = GroupApplicantsPicker._label(applicant.trustTier);
    final verification = GroupApplicantsPicker._label(
      applicant.verificationStatus,
    );

    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: SketchBox(
          seed: seed,
          radius: 14,
          fill: checked ? SketchColors.ink.withValues(alpha: 0.08) : null,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: selectable && !disabled ? onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    UserAvatar(avatarUrl: null, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            applicant.fullName.isNotEmpty
                                ? applicant.fullName
                                : 'Applicant',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Trust: $trust · $verification',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: SketchColors.inkFaint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (statusLabel != null)
                      SketchBox(
                        seed: seed + 2,
                        radius: 10,
                        fill: null,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        child: Text(
                          statusLabel!,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: SketchColors.inkFaint,
                          ),
                        ),
                      )
                    else
                      SketchBox(
                        seed: seed + 1,
                        radius: 8,
                        width: 28,
                        height: 28,
                        fill: checked ? SketchColors.ink : null,
                        padding: EdgeInsets.zero,
                        child: Center(
                          child: checked
                              ? Icon(
                                  Icons.check,
                                  size: 18,
                                  color: SketchColors.paper,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
