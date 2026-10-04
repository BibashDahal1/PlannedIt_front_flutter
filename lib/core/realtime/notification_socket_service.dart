import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/env.dart';
import 'notification_event.dart';

/// One connection per login session, held open in the background for
/// the whole app lifetime (per PRD 11.3), reconnecting automatically
/// on drop rather than requiring the person to reopen a screen.
class NotificationSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  final _eventController = StreamController<NotificationEvent>.broadcast();
  String? _currentToken;
  bool _disposed = false;
  Timer? _reconnectTimer;

  Stream<NotificationEvent> get events => _eventController.stream;

  void connect(String accessToken) {
    if (_currentToken == accessToken && _channel != null) return;
    _currentToken = accessToken;
    _disposed = false;
    _openSocket();
  }

  void _openSocket() {
    if (_currentToken == null || _disposed) return;
    _subscription?.cancel();
    try {
      final uri = Uri.parse(
        '${Env.wsBaseUrl}/ws/notifications/',
      ).replace(queryParameters: {'token': _currentToken});
      _channel = WebSocketChannel.connect(uri);
      _subscription = _channel!.stream.listen(
        (raw) {
          try {
            final json = jsonDecode(raw as String) as Map<String, dynamic>;
            _eventController.add(NotificationEvent.fromJson(json));
          } catch (_) {
            // Ignore malformed frames rather than crashing the listener.
          }
        },
        onDone: _scheduleReconnect,
        onError: (_) => _scheduleReconnect(),
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_disposed || _currentToken == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 4), _openSocket);
  }

  void disconnect() {
    _disposed = true;
    _currentToken = null;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _eventController.close();
  }
}
