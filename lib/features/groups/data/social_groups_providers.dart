import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/realtime/notification_providers.dart';
// `show` imports only dioClientProvider, so nothing else from the auth
// providers file can clash with names in this feature.
import '../../auth/data/auth_providers.dart' show dioClientProvider;
import '../domain/social_group.dart';

/// Accepts either a plain JSON array or a paginated `{results: [...]}`.
List<dynamic> _asList(dynamic data) {
  if (data is List) return data;
  if (data is Map && data['results'] is List) return data['results'] as List;
  return const [];
}

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

  /// Direct JSON array (not paginated). Only groups the user has joined.
  Future<List<SocialGroup>> mine() async {
    final res = await _dio.get(ApiEndpoints.mySocialGroups);
    return _asList(
      res.data,
    ).map((e) => SocialGroup.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Creates the group with only the creator in it. Everyone in [memberIds]
  /// receives an invitation and joins only after accepting.
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

  // ---------------- Invitations ----------------

  Future<List<SocialGroupInvitation>> invitations() async {
    final res = await _dio.get(ApiEndpoints.socialGroupInvitations);
    return _asList(res.data)
        .map((e) => SocialGroupInvitation.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SocialGroup> acceptInvitation(String invitationId) async {
    final res = await _dio.post(
      ApiEndpoints.socialGroupInvitationAccept(invitationId),
    );
    return SocialGroup.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> declineInvitation(String invitationId) async {
    await _dio.post(ApiEndpoints.socialGroupInvitationDecline(invitationId));
  }

  /// Admin cancels a pending invitation.
  Future<void> cancelInvitation(String groupId, String invitationId) async {
    await _dio.delete(
      ApiEndpoints.socialGroupInvitationCancel(groupId, invitationId),
    );
  }

  // ---------------- Admin actions ----------------

  /// Invites one more person (they join only after accepting).
  Future<void> inviteMember(String groupId, String userId) async {
    await _dio.post(
      ApiEndpoints.socialGroupMembers(groupId),
      data: {'user_id': userId},
    );
  }

  /// Removes a member. Admin only; the admin cannot remove themselves.
  Future<void> removeMember(String groupId, String userId) async {
    await _dio.delete(ApiEndpoints.socialGroupMember(groupId, userId));
  }

  /// Deletes the whole group and its chat. Admin only.
  Future<void> deleteGroup(String groupId) async {
    await _dio.delete(ApiEndpoints.socialGroupDetail(groupId));
  }

  // ---------------- Chat (REST part) ----------------

  /// Short-lived token for the social group chat WebSocket.
  Future<String> chatToken(String groupId) async {
    final res = await _dio.get(ApiEndpoints.socialGroupChatToken(groupId));
    return (res.data as Map<String, dynamic>)['channel_token'] as String;
  }

  /// Most recent page of history, already in chronological order.
  Future<List<Map<String, dynamic>>> messages(String groupId) async {
    final res = await _dio.get(
      ApiEndpoints.socialGroupMessages(groupId),
      queryParameters: {'page': 1},
    );
    return _asList(
      res.data,
    ).map((e) => Map<String, dynamic>.from(e as Map)).toList();
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

final socialGroupInvitationsProvider =
    FutureProvider.autoDispose<List<SocialGroupInvitation>>((ref) {
      return ref.watch(socialGroupsRepositoryProvider).invitations();
    });

/// Watch this once from a screen: it listens to the live notification socket
/// and refreshes groups / invitations when the backend says they changed.
final socialGroupLiveRefreshProvider = Provider<void>((ref) {
  const events = {
    'social_group_invitation',
    'social_group_invitation_accepted',
    'social_group_invitation_declined',
    'social_group_updated',
    'social_group_deleted',
  };
  final sub = ref.watch(notificationSocketServiceProvider).events.listen((e) {
    if (events.contains(e.event)) {
      ref.invalidate(mySocialGroupsProvider);
      ref.invalidate(socialGroupInvitationsProvider);
    }
  });
  ref.onDispose(sub.cancel);
});
