import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/env.dart';
import '../domain/chat_message.dart';
import 'chat_api.dart';

/// Same lifecycle as [ChatSocketService] (proactive token refresh, silent
/// socket swap, backoff reconnect) but for a social group's chat room:
/// /ws/social-groups/{id}/chat/. It also reports when the server closes the
/// socket with code 4003, which means the admin removed this person.
class SocialChatSocketService {
  SocialChatSocketService({required this.socialGroupId, required this.chatApi});

  final String socialGroupId;
  final ChatApi chatApi;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _proactiveRefreshTimer;
  Timer? _reconnectTimer;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  final _removedController = StreamController<void>.broadcast();
  bool _isConnected = false;
  bool _disposed = false;
  bool _removed = false;
  int _retryAttempt = 0;

  /// Last connection error, to help diagnose "always reconnecting".
  String? lastError;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;

  /// Fires once if this person was removed from the group.
  Stream<void> get removed => _removedController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() => _connect(reportDisconnectOnFailure: true);

  Future<void> _connect({required bool reportDisconnectOnFailure}) async {
    if (_disposed || _removed) return;
    try {
      final (token, expiresIn) = await chatApi.fetchSocialChatToken(
        socialGroupId,
      );
      final uri = Uri.parse(
        '${Env.wsBaseUrl}/ws/social-groups/$socialGroupId/chat/',
      ).replace(queryParameters: {'token': token});

      final newChannel = WebSocketChannel.connect(uri);
      await newChannel.ready;
      if (_disposed || _removed) {
        newChannel.sink.close();
        return;
      }

      // Swap only once the new socket is open, so a send mid-refresh never
      // hits a half-closed socket.
      final oldChannel = _channel;
      final oldSubscription = _subscription;
      _channel = newChannel;
      _subscription = newChannel.stream.listen(
        (raw) {
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            _messageController.add(ChatMessage.fromJson(json));
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onDone: () => _handleUnexpectedDisconnect(newChannel.closeCode),
        onError: (_) => _handleUnexpectedDisconnect(null),
        cancelOnError: false,
      );
      oldSubscription?.cancel();
      oldChannel?.sink.close();

      lastError = null;
      _isConnected = true;
      _retryAttempt = 0;
      _connectionStateController.add(true);

      _proactiveRefreshTimer?.cancel();
      final refreshDelay = Duration(
        seconds: (expiresIn - 30).clamp(10, expiresIn),
      );
      _proactiveRefreshTimer = Timer(
        refreshDelay,
        () => _connect(reportDisconnectOnFailure: false),
      );
    } catch (e) {
      lastError = e.toString();
      debugPrint('Social chat connect failed: $e');
      if (reportDisconnectOnFailure) {
        _isConnected = false;
        _connectionStateController.add(false);
      }
      _scheduleReconnect();
    }
  }

  void _handleUnexpectedDisconnect(int? closeCode) {
    if (_disposed) return;
    _isConnected = false;
    _connectionStateController.add(false);

    // 4003: the admin removed this person. Do not reconnect.
    if (closeCode == 4003) {
      _removed = true;
      _proactiveRefreshTimer?.cancel();
      _reconnectTimer?.cancel();
      _removedController.add(null);
      return;
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed || _removed) return;
    _reconnectTimer?.cancel();
    const backoffSeconds = [1, 2, 4, 6, 8];
    final delay =
        backoffSeconds[_retryAttempt.clamp(0, backoffSeconds.length - 1)];
    _retryAttempt++;
    _reconnectTimer = Timer(
      Duration(seconds: delay),
      () => _connect(reportDisconnectOnFailure: true),
    );
  }

  /// Returns false if it couldn't send (not connected) so the caller can
  /// queue it instead of losing it.
  bool send(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.length > 2000) return false;
    if (!_isConnected || _channel == null) return false;
    try {
      _channel!.sink.add(jsonEncode({'content': trimmed}));
      return true;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _disposed = true;
    _proactiveRefreshTimer?.cancel();
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _messageController.close();
    _connectionStateController.close();
    _removedController.close();
  }
}
