import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/app_user.dart';
import '../domain/otp_models.dart';

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

class AuthApi {
  AuthApi(this._dio);
  final Dio _dio;

  // --- Signup (first-time only; server rejects an already-registered phone) ---

  Future<OtpRequestResult> signupRequestOtp({
    required String phoneNumber,
    required String email,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.signupRequest,
      data: {'phone_number': phoneNumber, 'email': email},
    );
    return OtpRequestResult(
      expiresInMinutes: response.data['expires_in_minutes'] as int,
      debugCode: response.data['debug_code'] as String?,
    );
  }

  Future<OtpVerifyResult> signupVerifyOtp({
    required String phoneNumber,
    required String code,
    required String fullName,
    required DateTime dateOfBirth,
    required bool agreeToTerms,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.signupVerify,
      data: {
        'phone_number': phoneNumber,
        'code': code,
        'full_name': fullName,
        'date_of_birth': _isoDate(dateOfBirth),
        'agree_to_terms': agreeToTerms,
      },
    );
    return OtpVerifyResult(
      accessToken: response.data['access'] as String,
      refreshToken: response.data['refresh'] as String,
      user: AppUser.fromJson(response.data['user'] as Map<String, dynamic>),
    );
  }

  // --- Login (existing accounts only; no email field, always goes to email on file) ---

  Future<OtpRequestResult> loginRequestOtp({
    required String phoneNumber,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.loginRequest,
      data: {'phone_number': phoneNumber},
    );
    return OtpRequestResult(
      expiresInMinutes: response.data['expires_in_minutes'] as int,
      debugCode: response.data['debug_code'] as String?,
    );
  }

  Future<OtpVerifyResult> loginVerifyOtp({
    required String phoneNumber,
    required String code,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.loginVerify,
      data: {'phone_number': phoneNumber, 'code': code},
    );
    return OtpVerifyResult(
      accessToken: response.data['access'] as String,
      refreshToken: response.data['refresh'] as String,
      user: AppUser.fromJson(response.data['user'] as Map<String, dynamic>),
    );
  }

  // --- Shared, unchanged ---

  Future<AppUser> fetchMe() async {
    final response = await _dio.get(ApiEndpoints.me);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppUser> updateMeText(Map<String, dynamic> patch) async {
    final response = await _dio.patch(ApiEndpoints.me, data: patch);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AppUser> updateMeWithAvatar({
    String? fullName,
    required List<int> avatarBytes,
    required String avatarFilename,
  }) async {
    final formData = FormData.fromMap({
      if (fullName != null) 'full_name': fullName,
      'avatar': MultipartFile.fromBytes(avatarBytes, filename: avatarFilename),
    });
    final response = await _dio.patch(ApiEndpoints.me, data: formData);
    return AppUser.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> logout(String refreshToken) async {
    await _dio.post(ApiEndpoints.logout, data: {'refresh': refreshToken});
  }
}
