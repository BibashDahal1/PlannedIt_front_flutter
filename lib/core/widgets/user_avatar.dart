import 'package:flutter/material.dart';
import '../theme/sketch_colors.dart';
import 'sketch_icon.dart';

/// Shows a user's avatar photo when available, with a hand-drawn
/// fallback -- and actually falls back when the image fails to load.
/// A plain CircleAvatar won't do this: its `child` only renders when
/// `backgroundImage` is null to begin with, so a failed network image
/// just stays blank forever instead of showing anything.
class UserAvatar extends StatefulWidget {
  final String? avatarUrl;
  final double radius;
  const UserAvatar({super.key, required this.avatarUrl, this.radius = 20});

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  bool _failed = false;

  @override
  void didUpdateWidget(covariant UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.avatarUrl != widget.avatarUrl) {
      _failed = false; // a new URL deserves a fresh attempt
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.avatarUrl;
    final showImage = url != null && url.isNotEmpty && !_failed;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: SketchColors.paperFleck.withValues(alpha: 0.4),
      backgroundImage: showImage ? NetworkImage(url) : null,
      onBackgroundImageError: showImage
          ? (error, stackTrace) {
              // This fires during image resolution, not during build --
              // defer the setState to the next frame to avoid the
              // "setState during build" assertion.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _failed = true);
              });
            }
          : null,
      child: showImage
          ? null
          : SketchIcon('profile', size: widget.radius * 0.9),
    );
  }
}
