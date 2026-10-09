import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
// `show` imports only dioClientProvider, so nothing else from the auth
// providers file can clash with names in this feature.
import '../../auth/data/auth_providers.dart' show dioClientProvider;
import '../domain/social_group.dart';

class SocialGroupsRepository {
  SocialGroupsRepository(this._dio);

  final Dio _dio;

  /// People the user has met via accepted activity groups. The endpoint is
  /// paginated, so walk every page (max page size is 100).
  Future<List<EligibleMember>> eligibleMembers() async {
    final all = <EligibleMember>[];
    var page = 1;
    while (true) {
      final res = await _dio.get(
        ApiEndpoints.socialGroupEligibleMembers,
        queryParameters: {'page': page, 'page_size': 100},
      );
      final data = res.data as Map<String, dynamic>;
      all.addAll(
        (data['results'] as List).map(
          (e) => EligibleMember.fromJson(e as Map<String, dynamic>),
        ),
      );
      if (data['has_next'] != true) break;
      page++;
    }
    return all;
  }

  /// Direct JSON array (not paginated).
  Future<List<SocialGroup>> mine() async {
    final res = await _dio.get(ApiEndpoints.mySocialGroups);
    return (res.data as List)
        .map((e) => SocialGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// The creator becomes admin automatically, so at most 9 ids may be sent.
  Future<SocialGroup> create({
    required String name,
    required List<String> memberIds,
  }) async {
    final res = await _dio.post(
      ApiEndpoints.socialGroups,
      data: {'name': name, 'member_ids': memberIds},
    );
    return SocialGroup.fromJson(res.data as Map<String, dynamic>);
  }
}

final socialGroupsRepositoryProvider = Provider<SocialGroupsRepository>(
  (ref) => SocialGroupsRepository(ref.watch(dioClientProvider).dio),
);

final mySocialGroupsProvider = FutureProvider.autoDispose<List<SocialGroup>>((
  ref,
) {
  return ref.watch(socialGroupsRepositoryProvider).mine();
});

final eligibleMembersProvider =
    FutureProvider.autoDispose<List<EligibleMember>>((ref) {
      return ref.watch(socialGroupsRepositoryProvider).eligibleMembers();
    });
