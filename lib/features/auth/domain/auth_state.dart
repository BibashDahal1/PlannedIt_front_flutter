import 'app_user.dart';

enum AuthStatus { unauthenticated, authenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;

  const AuthState._(this.status, this.user);
  const AuthState.unauthenticated() : this._(AuthStatus.unauthenticated, null);
  const AuthState.authenticated(AppUser user)
    : this._(AuthStatus.authenticated, user);

  bool get isLoggedIn => status == AuthStatus.authenticated;
}
