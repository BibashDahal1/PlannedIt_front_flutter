import 'package:flutter/material.dart';

import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/user_avatar.dart';
import '../domain/social_group.dart';

/// One member of a social group, drawn as a sketch-style row:
/// avatar, name, and an "Admin" / "Member" pill.
class SocialGroupMemberTile extends StatelessWidget {
  final SocialGroupMember member;

  /// When set (group admin viewing another member) shows a remove button.
  final VoidCallback? onRemove;
  const SocialGroupMemberTile({super.key, required this.member, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final seed = member.id.hashCode;
    final name = member.fullName.isNotEmpty
        ? member.fullName
        : 'Unknown member';

    return SketchBox(
      seed: seed,
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          UserAvatar(avatarUrl: member.avatar, radius: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          member.isAdmin
              // Admin: solid ink pill with inverted text.
              ? SketchBox(
                  seed: seed + 1,
                  radius: 10,
                  fill: SketchColors.ink,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  child: Text(
                    'Admin',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SketchColors.paper,
                    ),
                  ),
                )
              // Member: outlined pill.
              : SketchBox(
                  seed: seed + 1,
                  radius: 10,
                  fill: null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  child: Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: SketchColors.inkFaint,
                    ),
                  ),
                ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove from group',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.person_remove_outlined, size: 20),
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}
