import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/notification_inbox_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chat_providers.dart';
import '../data/chat_socket_service.dart';
import '../domain/chat_message.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  const ChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  ChatSocketService? _socketService;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<ChatMessage>? _messageSubscription;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};
  final List<String> _pendingMessages = [];

  bool _isLoadingHistory = true;
  bool _isSocketReady = false;
  bool _showConnectingBanner =
      false; // debounced -- only true after a sustained drop
  Timer? _connectingBannerDebounce;
  String? _loadError;
  bool _isActive = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(notificationInboxProvider.notifier).openChat(widget.groupId);
      }
    });
    _init();
  }

  Future<void> _init() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      final history = await ref
          .read(chatApiProvider)
          .fetchMessages(widget.groupId);
      if (!mounted || !_isActive) return;
      setState(() {
        _mergeMessages(history);
        _isLoadingHistory = false;
      });
      _scrollToBottom();

      final service = ChatSocketService(
        groupId: widget.groupId,
        chatApi: ref.read(chatApiProvider),
      );
      _socketService = service;
      _listenToSocket(service);

      await service.connect();
    } catch (e) {
      if (!mounted || !_isActive) return;
      setState(() {
        _isLoadingHistory = false;
        _loadError = e.toString();
      });
    } finally {
      _isInitializing = false;
    }
  }

  void _listenToSocket(ChatSocketService service) {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _isSocketReady = service.isConnected;

    _connectionSubscription = service.connectionState.listen((connected) {
      if (!mounted || !_isActive) return;
      setState(() {
        _isSocketReady = connected;
        if (connected) _showConnectingBanner = false;
      });
      _connectingBannerDebounce?.cancel();
      if (connected) {
        _flushPendingMessages();
      } else {
        // Avoid rebuilding while a keyed route/widget is being deactivated.
        _connectingBannerDebounce = Timer(
          const Duration(milliseconds: 700),
          () {
            if (!mounted || !_isActive || _isSocketReady) return;
            setState(() => _showConnectingBanner = true);
          },
        );
      }
    });

    _messageSubscription = service.messages.listen((message) {
      if (!mounted || !_isActive) return;
      var added = false;
      setState(() => added = _mergeMessages([message]));
      if (added) _scrollToBottom();
    });
  }

  @override
  void activate() {
    super.activate();
    _isActive = true;
    final service = _socketService;
    if (service != null) _listenToSocket(service);
    if (service == null && _isLoadingHistory) _init();
  }

  @override
  void deactivate() {
    _isActive = false;
    _connectingBannerDebounce?.cancel();
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _connectionSubscription = null;
    _messageSubscription = null;
    super.deactivate();
  }

  bool _mergeMessages(Iterable<ChatMessage> incoming) {
    var changed = false;
    for (final message in incoming) {
      if (_messageIds.add(message.id)) {
        _messages.add(message);
        changed = true;
      }
    }
    if (changed) {
      _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }
    return changed;
  }

  void _flushPendingMessages() {
    if (_pendingMessages.isEmpty || _socketService == null) return;
    final toSend = List<String>.from(_pendingMessages);
    _pendingMessages.clear();
    for (final content in toSend) {
      final sent = _socketService!.send(content);
      if (!sent) _pendingMessages.add(content); // still not ready, keep queued
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _isActive && _scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Input stays enabled at all times -- if the socket happens to be
  /// mid-reconnect right when the person hits send, the message is
  /// queued locally and flushed automatically the moment the
  /// connection is back, rather than the person losing it or being
  /// blocked from typing.
  void _send() {
    if (!mounted || !_isActive) return;
    final content = _messageController.text.trim();
    if (content.isEmpty) return;
    _messageController.clear();

    final sent = _socketService?.send(content) ?? false;
    if (!sent) {
      _pendingMessages.add(content);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Reconnecting — your message will send automatically.',
            ),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    ref.read(notificationInboxProvider.notifier).closeChat(widget.groupId);
    _connectingBannerDebounce?.cancel();
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _socketService?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).value?.user?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                ? Center(child: Text('Could not load chat: $_loadError'))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final message = _messages[i];
                      final isMine = message.senderId == currentUserId;
                      return Align(
                        alignment: isMine
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                          decoration: BoxDecoration(
                            color: isMine
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: isMine
                                ? null
                                : Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Text(
                                  message.senderName,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              Text(
                                message.content,
                                style: TextStyle(
                                  color: isMine
                                      ? Colors.white
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Small, non-blocking strip -- never covers or disables the
          // input, and only appears after the debounce window above.
          if (_showConnectingBanner)
            Container(
              width: double.infinity,
              color: AppColors.primarySoft,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: const Text(
                'Reconnecting...',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.primary, fontSize: 11),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _send,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
