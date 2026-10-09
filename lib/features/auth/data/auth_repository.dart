import '../../../core/storage/secure_token_storage.dart';
import '../domain/app_user.dart';
import '../domain/otp_models.dart';
import 'auth_api.dart';

class AuthRepository {
  AuthRepository(this._api, this._tokenStorage);
  final AuthApi _api;
  final SecureTokenStorage _tokenStorage;

  Future<OtpRequestResult> signupRequestOtp({
    required String phoneNumber,
    required String email,
  }) {
    return _api.signupRequestOtp(phoneNumber: phoneNumber, email: email);
  }

  Future<AppUser> signupVerifyOtp({
    required String phoneNumber,
    required String code,
    required String fullName,
    required DateTime dateOfBirth,
    required bool agreeToTerms,
  }) async {
    final result = await _api.signupVerifyOtp(
      phoneNumber: phoneNumber,
      code: code,
      fullName: fullName,
      dateOfBirth: dateOfBirth,
      agreeToTerms: agreeToTerms,
    );
    await _tokenStorage.saveTokens(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    return result.user;
  }

  Future<OtpRequestResult> loginRequestOtp({required String phoneNumber}) {
    return _api.loginRequestOtp(phoneNumber: phoneNumber);
  }

  Future<AppUser> loginVerifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final result = await _api.loginVerifyOtp(
      phoneNumber: phoneNumber,
      code: code,
    );
    await _tokenStorage.saveTokens(
      access: result.accessToken,
      refresh: result.refreshToken,
    );
    return result.user;
  }

  /// Called once on app startup.
  Future<AppUser?> restoreSession() async {
    final access = await _tokenStorage.accessToken;
    if (access == null) return null;
    return _api.fetchMe();
  }

  Future<AppUser> updateProfileText(Map<String, dynamic> patch) =>
      _api.updateMeText(patch);

  Future<AppUser> updateProfileWithAvatar({
    String? fullName,
    required List<int> avatarBytes,
    required String avatarFilename,
  }) => _api.updateMeWithAvatar(
    fullName: fullName,
    avatarBytes: avatarBytes,
    avatarFilename: avatarFilename,
  );

  Future<void> logout() async {
    final refresh = await _tokenStorage.refreshToken;
    if (refresh != null) {
      try {
        await _api.logout(refresh);
      } catch (_) {
        // Local logout still proceeds even if the server call fails.
      }
    }
    await _tokenStorage.clear();
  }

  Future<AppUser> fetchCurrentUser() => _api.fetchMe();
}
