import 'package:flutter/material.dart';
import '../config/env.dart';
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
  bool _isActive = true;

  String _resolvedAvatarUrl(String url) {
    final avatarUri = Uri.tryParse(url);
    final apiUri = Uri.tryParse(Env.apiBaseUrl);
    if (avatarUri == null || apiUri == null || !avatarUri.hasAuthority) {
      return url;
    }
    final avatarHost = avatarUri.host.toLowerCase();
    if (avatarHost != 'localhost' &&
        avatarHost != '127.0.0.1' &&
        avatarHost != '0.0.0.0' &&
        avatarHost != '::1') {
      return url;
    }
    return Uri(
      scheme: apiUri.scheme,
      host: apiUri.host,
      port: apiUri.hasPort ? apiUri.port : null,
      path: avatarUri.path,
      query: avatarUri.hasQuery ? avatarUri.query : null,
      fragment: avatarUri.hasFragment ? avatarUri.fragment : null,
    ).toString();
  }

  @override
  void didUpdateWidget(covariant UserAvatar old) {
    super.didUpdateWidget(old);
    if (old.avatarUrl != widget.avatarUrl) {
      _failed = false; // a new URL deserves a fresh attempt
    }
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
  }

  @override
  void deactivate() {
    _isActive = false;
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final url = widget.avatarUrl;
    final showImage = url != null && url.isNotEmpty && !_failed;
    final resolvedUrl = showImage ? _resolvedAvatarUrl(url) : null;
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: SketchColors.paperFleck.withValues(alpha: 0.4),
      backgroundImage: resolvedUrl != null ? NetworkImage(resolvedUrl) : null,
      onBackgroundImageError: showImage
          ? (error, stackTrace) {
              // This fires during image resolution, not during build --
              // defer the setState to the next frame to avoid the
              // "setState during build" assertion.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _isActive) setState(() => _failed = true);
              });
            }
          : null,
      child: showImage
          ? null
          : SketchIcon('profile', size: widget.radius * 0.9),
    );
  }
}
