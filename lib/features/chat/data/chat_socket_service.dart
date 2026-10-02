import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../../core/config/env.dart';
import '../domain/chat_message.dart';
import 'chat_api.dart';

/// One instance per open ChatScreen. Owns its own reconnect lifecycle:
/// - Proactively refreshes the token ~30s before it expires and swaps
///   sockets silently (never reports "disconnected" for this case),
///   since a 5-minute token would otherwise force a visible drop
///   partway through every conversation.
/// - On an unexpected drop, retries with short backoff, fetching a
///   fresh token each attempt (the old one may already be stale).
class ChatSocketService {
  ChatSocketService({required this.groupId, required this.chatApi});

  final String groupId;
  final ChatApi chatApi;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _proactiveRefreshTimer;
  Timer? _reconnectTimer;
  final _messageController = StreamController<ChatMessage>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();
  bool _isConnected = false;
  bool _disposed = false;
  int _retryAttempt = 0;

  Stream<ChatMessage> get messages => _messageController.stream;
  Stream<bool> get connectionState => _connectionStateController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect() => _connect(reportDisconnectOnFailure: true);

  Future<void> _connect({required bool reportDisconnectOnFailure}) async {
    if (_disposed) return;
    try {
      final (token, expiresIn) = await chatApi.fetchChatToken(groupId);
      final uri = Uri.parse(
        '${Env.wsBaseUrl}/ws/groups/$groupId/chat/',
      ).replace(queryParameters: {'token': token});

      final newChannel = WebSocketChannel.connect(uri);
      await newChannel.ready;
      if (_disposed) {
        newChannel.sink.close();
        return;
      }

      // Swap to the new channel only once it's actually open, so a send
      // mid-refresh never hits a half-closed socket.
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
        onDone: _handleUnexpectedDisconnect,
        onError: (_) => _handleUnexpectedDisconnect(),
        cancelOnError: false,
      );
      oldSubscription?.cancel();
      oldChannel?.sink.close();

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
    } catch (_) {
      if (reportDisconnectOnFailure) {
        _isConnected = false;
        _connectionStateController.add(false);
      }
      _scheduleReconnect();
    }
  }

  void _handleUnexpectedDisconnect() {
    if (_disposed) return;
    _isConnected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_disposed) return;
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

  /// Matches the server's silent-drop rule (empty or >2000 chars).
  /// Returns false if it couldn't send (not connected) so the caller
  /// can decide to queue it instead of losing it.
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
  }
}
