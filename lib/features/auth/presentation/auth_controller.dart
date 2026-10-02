import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/auth_providers.dart';
import '../domain/auth_state.dart';
import '../domain/otp_models.dart';

class AuthController extends AsyncNotifier<AuthState> {
  @override
  Future<AuthState> build() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    return user != null
        ? AuthState.authenticated(user)
        : const AuthState.unauthenticated();
  }

  Future<OtpRequestResult> signupRequestOtp({
    required String phoneNumber,
    required String email,
  }) {
    return ref
        .read(authRepositoryProvider)
        .signupRequestOtp(phoneNumber: phoneNumber, email: email);
  }

  Future<void> signupVerifyOtp({
    required String phoneNumber,
    required String code,
    required String fullName,
    required DateTime dateOfBirth,
    required bool agreeToTerms,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .signupVerifyOtp(
            phoneNumber: phoneNumber,
            code: code,
            fullName: fullName,
            dateOfBirth: dateOfBirth,
            agreeToTerms: agreeToTerms,
          );
      return AuthState.authenticated(user);
    });
  }

  Future<OtpRequestResult> loginRequestOtp({required String phoneNumber}) {
    return ref
        .read(authRepositoryProvider)
        .loginRequestOtp(phoneNumber: phoneNumber);
  }

  Future<void> loginVerifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await ref
          .read(authRepositoryProvider)
          .loginVerifyOtp(phoneNumber: phoneNumber, code: code);
      return AuthState.authenticated(user);
    });
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthState.unauthenticated());
  }

  Future<void> updateProfileText(Map<String, dynamic> patch) async {
    final updatedUser = await ref
        .read(authRepositoryProvider)
        .updateProfileText(patch);
    state = AsyncData(AuthState.authenticated(updatedUser));
  }

  Future<void> updateProfileWithAvatar({
    String? fullName,
    required List<int> avatarBytes,
    required String avatarFilename,
  }) async {
    final updatedUser = await ref
        .read(authRepositoryProvider)
        .updateProfileWithAvatar(
          fullName: fullName,
          avatarBytes: avatarBytes,
          avatarFilename: avatarFilename,
        );
    state = AsyncData(AuthState.authenticated(updatedUser));
  }

  Future<void> refreshProfile() async {
    final current = state.value;
    if (current == null || !current.isLoggedIn) return;
    try {
      final user = await ref.read(authRepositoryProvider).fetchCurrentUser();
      state = AsyncData(AuthState.authenticated(user));
    } catch (_) {
      // Keep whatever's already cached -- a transient refresh failure
      // shouldn't log anyone out or show an error on Home.
    }
  }
}

final authControllerProvider = AsyncNotifierProvider<AuthController, AuthState>(
  AuthController.new,
);
