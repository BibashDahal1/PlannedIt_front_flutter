import 'package:go_router/go_router.dart';
import '../widgets/main_scaffold.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/discovery/presentation/home_screen.dart';
import '../../features/discovery/presentation/map_screen.dart';
import '../../features/activities/presentation/post_activity_screen.dart';
import '../../features/chat/presentation/chats_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/otp_verify_screen.dart';
import '../../features/auth/domain/auth_flow_mode.dart';
import '../../features/activities/presentation/activity_detail_screen.dart';
import '../../features/join_requests/presentation/requests_screen.dart';
import '../../features/join_requests/presentation/incoming_requests_screen.dart';
import '../../features/trust/presentation/public_profile_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/legal/presentation/legal_document_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const WelcomeScreen(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingScreen(),
    ),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/signup', builder: (context, state) => const SignupScreen()),
    GoRoute(
      path: '/otp-verify',
      builder: (context, state) {
        final args = state.extra as Map<String, dynamic>;
        return OtpVerifyScreen(
          mode: args['mode'] as AuthFlowMode,
          phoneNumber: args['phone'] as String,
          email: args['email'] as String?,
          fullName: args['fullName'] as String?,
          dateOfBirth: args['dateOfBirth'] as DateTime?,
        );
      },
    ),
    GoRoute(
      path: '/activity/:id',
      builder: (context, state) =>
          ActivityDetailScreen(activityId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/activity/:id/requests',
      builder: (context, state) =>
          IncomingRequestsScreen(activityId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/requests',
      builder: (context, state) => const RequestsScreen(),
    ),
    GoRoute(
      path: '/profile/:userId/public',
      builder: (context, state) => PublicProfileScreen(
        userId: state.pathParameters['userId']!,
        activityId: state.uri.queryParameters['activityId'],
      ),
    ),
    GoRoute(
      path: '/group/:groupId/chat',
      builder: (context, state) =>
          ChatScreen(groupId: state.pathParameters['groupId']!),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/legal/:documentType',
      builder: (context, state) => LegalDocumentScreen(
        documentType: state.pathParameters['documentType']!,
      ),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          MainScaffold(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/map',
              builder: (context, state) => const MapScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/post-activity',
              builder: (context, state) => const PostActivityScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/chats',
              builder: (context, state) => const ChatsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
