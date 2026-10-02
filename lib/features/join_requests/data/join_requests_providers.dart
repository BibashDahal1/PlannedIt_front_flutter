import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/join_request.dart';
import 'join_requests_api.dart';
import 'join_requests_repository.dart';

final joinRequestsApiProvider = Provider(
  (ref) => JoinRequestsApi(ref.watch(dioClientProvider).dio),
);
final joinRequestsRepositoryProvider = Provider(
  (ref) => JoinRequestsRepository(ref.watch(joinRequestsApiProvider)),
);

final myJoinRequestsProvider = FutureProvider<List<JoinRequest>>((ref) {
  return ref.watch(joinRequestsRepositoryProvider).fetchMyRequests();
});

final incomingRequestsProvider =
    FutureProvider.family<List<JoinRequest>, String>((ref, activityId) {
      return ref
          .watch(joinRequestsRepositoryProvider)
          .fetchIncomingRequests(activityId);
    });
