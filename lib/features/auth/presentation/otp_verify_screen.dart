import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../domain/auth_flow_mode.dart';
import 'auth_controller.dart';

class OtpVerifyScreen extends ConsumerStatefulWidget {
  final AuthFlowMode mode;
  final String phoneNumber;
  final String? email; // only present/used for signup resend

  final String? fullName;
  final DateTime? dateOfBirth;

  const OtpVerifyScreen({
    super.key,
    required this.mode,
    required this.phoneNumber,
    this.email,
    this.fullName,
    this.dateOfBirth,
  });

  @override
  ConsumerState<OtpVerifyScreen> createState() => _OtpVerifyScreenState();
}

class _OtpVerifyScreenState extends ConsumerState<OtpVerifyScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isResending = false;
  int _cooldownSeconds = 60;
  Timer? _timer;

  bool get _isSignup => widget.mode == AuthFlowMode.signup;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        setState(() => _cooldownSeconds = 0);
      } else {
        setState(() => _cooldownSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter the 6-digit code.')));
      return;
    }
    setState(() => _isVerifying = true);
    final notifier = ref.read(authControllerProvider.notifier);
    if (_isSignup) {
      await notifier.signupVerifyOtp(
        phoneNumber: widget.phoneNumber,
        code: code,
        fullName: widget.fullName!,
        dateOfBirth: widget.dateOfBirth!,
        agreeToTerms:
            true, // already gated on the Signup screen -- can't reach here otherwise
      );
    } else {
      await notifier.loginVerifyOtp(
        phoneNumber: widget.phoneNumber,
        code: code,
      );
    }
    if (!mounted) return;
    final state = ref.read(authControllerProvider);
    if (state.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(extractApiErrorMessage(state.error!))),
      );
      setState(() => _isVerifying = false);
    } else {
      context.go('/home');
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    try {
      final notifier = ref.read(authControllerProvider.notifier);
      if (_isSignup) {
        await notifier.signupRequestOtp(
          phoneNumber: widget.phoneNumber,
          email: widget.email!,
        );
      } else {
        await notifier.loginRequestOtp(phoneNumber: widget.phoneNumber);
      }
      _startCooldown();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Code resent.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify code')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the code sent to your email for ${widget.phoneNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, letterSpacing: 8),
              decoration: const InputDecoration(
                counterText: '',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verify,
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Verify & continue'),
            ),
            const SizedBox(height: 16),
            Center(
              child: _cooldownSeconds > 0
                  ? Text(
                      'Resend code in ${_cooldownSeconds}s',
                      style: Theme.of(context).textTheme.bodyMedium,
                    )
                  : TextButton(
                      onPressed: _isResending ? null : _resend,
                      child: _isResending
                          ? const Text('Resending...')
                          : const Text('Resend code'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
