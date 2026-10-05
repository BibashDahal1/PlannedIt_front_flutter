import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_error.dart';
import '../domain/age_eligibility.dart';
import '../domain/auth_flow_mode.dart';
import 'auth_controller.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController(text: '+977');
  final _emailController = TextEditingController();
  final _fullNameController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _agreeToTerms = false;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  bool _isAtLeast18(DateTime dob) {
    return isAtLeast18(dob);
  }

  Future<void> _pickDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(DateTime.now().year - 20, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date of birth',
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final dob = _dateOfBirth;
    if (dob == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick your date of birth.')));
      return;
    }
    // Mirrors the backend's rule client-side, so this is caught before
    // an API round trip rather than only after a 400 comes back.
    if (!_isAtLeast18(dob)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be at least 18 years old to sign up.'),
        ),
      );
      return;
    }
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please agree to the Privacy Policy and Terms of Service.',
          ),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .signupRequestOtp(phoneNumber: phone, email: email);
      if (!mounted) return;
      if (result.debugCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debug code: ${result.debugCode}')),
        );
      }
      context.push(
        '/otp-verify',
        extra: {
          'mode': AuthFlowMode.signup,
          'phone': phone,
          'email': email,
          'fullName': _fullNameController.text.trim(),
          'dateOfBirth': dob,
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(extractApiErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dob = _dateOfBirth;
    final dobLabel = dob == null
        ? 'Date of birth'
        : '${dob.year}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';

    return Scaffold(
      appBar: AppBar(title: const Text('Sign up')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Create your account',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text("We'll send a one-time code to your email to verify."),
            const SizedBox(height: 20),
            TextFormField(
              controller: _fullNameController,
              decoration: const InputDecoration(
                labelText: 'Full name',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                hintText: '+9779812345678',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                if (!RegExp(r'^\+\d{10,15}$').hasMatch(v)) {
                  return 'Enter a valid phone number with country code';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final v = value?.trim() ?? '';
                final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                if (!emailPattern.hasMatch(v)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _pickDateOfBirth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(dobLabel),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 4),
              child: Text(
                'You must be 18 or older to create an account.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _agreeToTerms,
              onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: Wrap(
                children: [
                  const Text('I agree to the '),
                  GestureDetector(
                    onTap: () => context.push('/legal/privacy_terms'),
                    child: const Text(
                      'Privacy Policy & Terms of Service',
                      style: TextStyle(
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send code'),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.pushReplacement('/login'),
                child: const Text('Already have an account? Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
