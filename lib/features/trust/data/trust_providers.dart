import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/pending_activity_rating.dart';
import '../domain/public_profile.dart';
import 'trust_api.dart';
import 'trust_repository.dart';

final trustApiProvider = Provider(
  (ref) => TrustApi(ref.watch(dioClientProvider).dio),
);
final trustRepositoryProvider = Provider(
  (ref) => TrustRepository(ref.watch(trustApiProvider)),
);

final pendingRatingsProvider = FutureProvider<List<PendingActivityRating>>((
  ref,
) {
  return ref.watch(trustRepositoryProvider).fetchPendingRatings();
});

final publicProfileProvider = FutureProvider.family<PublicProfile, String>((
  ref,
  userId,
) {
  return ref.watch(trustRepositoryProvider).fetchPublicProfile(userId);
});
