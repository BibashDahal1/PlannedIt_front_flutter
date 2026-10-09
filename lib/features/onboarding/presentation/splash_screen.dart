import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/domain/auth_state.dart';

/// Checks for internet access before restoring a stored session, then
/// routes to Home or Welcome. If offline, it keeps the logo visible and
/// lets the user retry or continue automatically when internet returns.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<InternetStatus>? _connectionSubscription;
  bool _isCheckingConnection = true;
  bool _isResolving = false;
  bool _retryAfterResolve = false;
  bool _authRestoreFailed = false;
  String? _connectionMessage;

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
    _connectionSubscription = InternetConnection().onStatusChange.listen(
      _handleConnectionStatus,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolve());
  }

  @override
  void dispose() {
    _connectionSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleConnectionStatus(InternetStatus status) {
    if (status == InternetStatus.connected) {
      if (_isResolving) {
        _retryAfterResolve = true;
        return;
      }
      _resolve();
    } else if (mounted) {
      setState(() {
        _isCheckingConnection = false;
        _connectionMessage =
            'No internet connection. Connect to the internet to continue.';
      });
    }
  }

  Future<void> _resolve() async {
    if (_isResolving) {
      if (_connectionMessage != null) _retryAfterResolve = true;
      return;
    }
    _isResolving = true;
    if (mounted) {
      setState(() {
        _isCheckingConnection = true;
        _connectionMessage = null;
      });
    }

    var attemptingSessionRestore = false;
    try {
      final hasInternet = await InternetConnection().hasInternetAccess.timeout(
        const Duration(seconds: 8),
      );
      if (!mounted) return;
      if (!hasInternet) {
        setState(() {
          _isCheckingConnection = false;
          _connectionMessage =
              'No internet connection. Connect to the internet to continue.';
        });
        return;
      }

      if (_authRestoreFailed) {
        ref.invalidate(authControllerProvider);
        _authRestoreFailed = false;
      }
      attemptingSessionRestore = true;
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
    } catch (_) {
      if (!mounted) return;
      _authRestoreFailed = attemptingSessionRestore;
      setState(() {
        _isCheckingConnection = false;
        _connectionMessage =
            'Could not connect to PlannedIt. Check your connection and try again.';
      });
    } finally {
      _isResolving = false;
      final shouldRetry = _retryAfterResolve && _connectionMessage != null;
      _retryAfterResolve = false;
      if (shouldRetry && mounted) {
        unawaited(_resolve());
      }
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
                if (_isCheckingConnection) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'Checking your internet connection…',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ] else if (_connectionMessage != null) ...[
                  const SizedBox(height: 24),
                  const Icon(Icons.wifi_off, size: 38),
                  const SizedBox(height: 10),
                  Text(
                    _connectionMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _resolve,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry connection'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
