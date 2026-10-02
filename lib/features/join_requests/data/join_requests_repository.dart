import '../domain/join_request.dart';
import 'join_requests_api.dart';

class JoinRequestsRepository {
  JoinRequestsRepository(this._api);
  final JoinRequestsApi _api;

  Future<JoinRequest> sendJoinRequest(String activityId, {String? message}) =>
      _api.sendJoinRequest(activityId, message: message);
  Future<List<JoinRequest>> fetchIncomingRequests(String activityId) =>
      _api.fetchIncomingRequests(activityId);
  Future<List<JoinRequest>> fetchMyRequests() => _api.fetchMyRequests();
  Future<JoinRequest> fetchJoinRequestDetail(String id) =>
      _api.fetchJoinRequestDetail(id);
  Future<JoinRequest> acceptJoinRequest(String id) =>
      _api.acceptJoinRequest(id);
  Future<JoinRequest> declineJoinRequest(String id, {String? reason}) =>
      _api.declineJoinRequest(id, reason: reason);
  Future<JoinRequest> withdrawJoinRequest(String id) =>
      _api.withdrawJoinRequest(id);
}
