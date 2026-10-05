import 'package:dio/dio.dart';
import '../../../core/network/api_response.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/chat_message.dart';

class ChatApi {
  ChatApi(this._dio);
  final Dio _dio;

  /// Returns (token, expiresInSeconds) so the socket service can
  /// proactively reconnect with a fresh token before this one expires,
  /// instead of waiting for the server to force-close the connection.
  Future<(String token, int expiresIn)> fetchChatToken(String groupId) async {
    final response = await _dio.get(ApiEndpoints.groupChatToken(groupId));
    return (
      response.data['channel_token'] as String,
      response.data['expires_in_seconds'] as int,
    );
  }

  Future<List<ChatMessage>> fetchMessages(
    String groupId, {
    DateTime? before,
  }) async {
    final response = await _dio.get(
      ApiEndpoints.groupMessages(groupId),
      queryParameters: before != null
          ? {'before': before.toUtc().toIso8601String()}
          : null,
    );
    return parseListResponse(
      response.data,
      ChatMessage.fromJson,
      resourceName: 'chat messages',
    );
  }
}
