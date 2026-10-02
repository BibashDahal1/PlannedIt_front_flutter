import 'package:flutter/material.dart';
import '../theme/sketch_colors.dart';

class PaperBackground extends StatelessWidget {
  final Widget child;
  const PaperBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: SketchColors.paper,
        image: isDark
            ? null
            : const DecorationImage(
                image: AssetImage('assets/images/sketch/paper_texture.png'),
                repeat: ImageRepeat.repeat,
              ),
      ),
      child: child,
    );
  }
}
