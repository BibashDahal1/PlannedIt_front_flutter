import 'app_user.dart';

class OtpRequestResult {
  final int expiresInMinutes;
  final String? debugCode; // only ever present when Django DEBUG=True
  const OtpRequestResult({required this.expiresInMinutes, this.debugCode});
}

class OtpVerifyResult {
  final String accessToken;
  final String refreshToken;
  final AppUser user;
  const OtpVerifyResult({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}
