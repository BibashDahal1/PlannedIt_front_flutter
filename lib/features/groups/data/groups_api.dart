import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/group_roster.dart';

class GroupsApi {
  GroupsApi(this._dio);
  final Dio _dio;

  Future<GroupRoster> fetchGroup(String id) async {
    final response = await _dio.get(ApiEndpoints.groupDetail(id));
    return GroupRoster.fromJson(response.data as Map<String, dynamic>);
  }
}
