import 'package:flutter/material.dart';
import '../theme/sketch_colors.dart';
import 'sketch_box.dart';

class SketchButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final bool filled;
  final bool isLoading;
  final bool danger;
  final int seed;

  const SketchButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.filled = false,
    this.isLoading = false,
    this.danger = false,
    this.seed = 1,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final foreground = filled
        ? SketchColors.paper
        : danger
        ? SketchColors.danger
        : SketchColors.ink;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: SketchBox(
          seed: seed,
          radius: 13,
          strokeColor: danger ? SketchColors.danger : null,
          fill: filled ? SketchColors.ink : null,
          width: double.infinity,
          padding: EdgeInsets.zero,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: enabled ? onPressed : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    else if (icon != null)
                      IconTheme(
                        data: IconThemeData(color: foreground, size: 18),
                        child: icon!,
                      ),
                    if (isLoading || icon != null)
                      const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontWeight: FontWeight.w700,
                        ),
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
