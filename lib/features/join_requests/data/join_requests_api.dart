import 'package:dio/dio.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/join_request.dart';

class JoinRequestsApi {
  JoinRequestsApi(this._dio);
  final Dio _dio;

  Future<JoinRequest> sendJoinRequest(
    String activityId, {
    String? message,
  }) async {
    final response = await _dio.post(
      ApiEndpoints.activityJoinRequests(activityId),
      data: {if (message != null && message.isNotEmpty) 'message': message},
    );
    return JoinRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<List<JoinRequest>> fetchIncomingRequests(String activityId) async {
    final response = await _dio.get(
      ApiEndpoints.activityJoinRequests(activityId),
    );
    return (response.data as List)
        .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<JoinRequest>> fetchMyRequests() async {
    final response = await _dio.get(ApiEndpoints.myJoinRequests);
    return (response.data as List)
        .map((e) => JoinRequest.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<JoinRequest> fetchJoinRequestDetail(String id) async {
    final response = await _dio.get(ApiEndpoints.joinRequestDetail(id));
    return JoinRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JoinRequest> acceptJoinRequest(String id) async {
    final response = await _dio.post(ApiEndpoints.joinRequestAccept(id));
    return JoinRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JoinRequest> declineJoinRequest(String id, {String? reason}) async {
    final response = await _dio.post(
      ApiEndpoints.joinRequestDecline(id),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    return JoinRequest.fromJson(response.data as Map<String, dynamic>);
  }

  Future<JoinRequest> withdrawJoinRequest(String id) async {
    final response = await _dio.post(ApiEndpoints.joinRequestWithdraw(id));
    return JoinRequest.fromJson(response.data as Map<String, dynamic>);
  }
}
