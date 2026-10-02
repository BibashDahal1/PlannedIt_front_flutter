import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

/// The real startup gate: shows the logo immediately, waits for
/// AuthController.build() to finish restoring (or failing to restore)
/// a session from stored tokens, then routes to Home if already
/// logged in, or Welcome otherwise. Nothing else in the app mounts
/// until this resolves.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  late final Animation<double> _scale = Tween<double>(
    begin: 0.88,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

  @override
  void initState() {
    super.initState();
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _resolve() async {
    // Runs in parallel with the entrance animation -- whichever takes
    // longer decides when we actually leave. Guarantees the logo is
    // never just a flash even if session restore is instant.
    final results = await Future.wait([
      ref.read(authControllerProvider.future),
      Future.delayed(const Duration(milliseconds: 900)),
    ]);
    if (!mounted) return;
    final authState = results[0] as AuthState;
    if (authState.isLoggedIn) {
      context.go('/home');
    } else {
      context.go('/welcome');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SketchColors.paper,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(
                      0xFFF6F3EC,
                    ), // fixed light card, not SketchColors.paper -- stays legible either theme
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Image.asset(
                    'assets/images/sketch/app_logo_full.png',
                    width: 220,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
