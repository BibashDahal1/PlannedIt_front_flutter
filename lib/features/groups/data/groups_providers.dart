import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_providers.dart';
import '../domain/group_roster.dart';
import 'groups_api.dart';

final groupsApiProvider = Provider(
  (ref) => GroupsApi(ref.watch(dioClientProvider).dio),
);

final groupRosterProvider = FutureProvider.family<GroupRoster, String>((
  ref,
  groupId,
) {
  return ref.watch(groupsApiProvider).fetchGroup(groupId);
});
