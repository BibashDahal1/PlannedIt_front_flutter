import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_endpoints.dart';
// `show` keeps this import from clashing with anything else.
import '../../auth/data/auth_providers.dart' show dioClientProvider;

/// One person inside a social-group application.
class GroupApplicant {
  final String id;
  final String fullName;
  final String verificationStatus;
  final String trustTier;

  /// pending | accepted | not_selected
  final String status;

  const GroupApplicant({
    required this.id,
    required this.fullName,
    required this.verificationStatus,
    required this.trustTier,
    required this.status,
  });

  bool get isPending => status == 'pending';

  factory GroupApplicant.fromJson(Map<String, dynamic> json) => GroupApplicant(
    id: json['id'] as String,
    fullName: (json['full_name'] as String?) ?? '',
    verificationStatus: (json['verification_status'] as String?) ?? '',
    trustTier: (json['trust_tier'] as String?) ?? '',
    status: (json['status'] as String?) ?? 'pending',
  );
}

/// The social-group part of a join request. Individual requests have none.
class GroupApplication {
  final String groupId;
  final String groupName;
  final List<GroupApplicant> applicants;

  const GroupApplication({
    required this.groupId,
    required this.groupName,
    required this.applicants,
  });
}

class GroupApplicationsRepository {
  GroupApplicationsRepository(this._dio);

  final Dio _dio;

  /// GET /join-requests/{id}. Returns null for an individual request
  /// (`applying_group` is null).
  Future<GroupApplication?> fetchApplication(String requestId) async {
    final res = await _dio.get(ApiEndpoints.joinRequestDetail(requestId));
    final data = res.data as Map<String, dynamic>;
    final group = data['applying_group'];
    if (group is! Map<String, dynamic>) return null;
    final applicants = ((data['applicants'] as List?) ?? const [])
        .map((e) => GroupApplicant.fromJson(e as Map<String, dynamic>))
        .toList();
    return GroupApplication(
      groupId: group['id'] as String,
      groupName: (group['name'] as String?) ?? 'Group',
      applicants: applicants,
    );
  }

  /// GET /activities/{id}: `spots_remaining` is only on the detail response.
  Future<int?> spotsRemaining(String activityId) async {
    final res = await _dio.get(ApiEndpoints.activityDetail(activityId));
    final data = res.data as Map<String, dynamic>;
    return (data['spots_remaining'] as num?)?.toInt();
  }

  /// POST /activities/{id}/join-requests in social-group mode.
  /// Caller must be the group's admin.
  Future<void> applyWithGroup({
    required String activityId,
    required String groupId,
    required List<String> memberIds,
    String? message,
  }) async {
    await _dio.post(
      ApiEndpoints.activityJoinRequests(activityId),
      data: {
        'group_id': groupId,
        'member_ids': memberIds,
        if (message != null && message.trim().isNotEmpty)
          'message': message.trim(),
      },
    );
  }

  /// POST /join-requests/{id}/accept with the selected applicants.
  /// Returns the resulting activity `group_id` when the server provides it.
  Future<String?> acceptSelected({
    required String requestId,
    required List<String> memberIds,
  }) async {
    final res = await _dio.post(
      ApiEndpoints.joinRequestAccept(requestId),
      data: {'member_ids': memberIds},
    );
    final data = res.data;
    if (data is Map<String, dynamic>) return data['group_id'] as String?;
    return null;
  }
}

final groupApplicationsRepositoryProvider =
    Provider<GroupApplicationsRepository>(
      (ref) => GroupApplicationsRepository(ref.watch(dioClientProvider).dio),
    );

/// Null for individual requests, a [GroupApplication] for group requests.
final groupApplicationProvider = FutureProvider.autoDispose
    .family<GroupApplication?, String>((ref, requestId) {
      return ref
          .watch(groupApplicationsRepositoryProvider)
          .fetchApplication(requestId);
    });

final spotsRemainingProvider = FutureProvider.autoDispose.family<int?, String>((
  ref,
  activityId,
) {
  return ref
      .watch(groupApplicationsRepositoryProvider)
      .spotsRemaining(activityId);
});
