import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/realtime/notification_inbox_provider.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/groups_providers.dart';
import '../data/chat_providers.dart';
import '../data/chat_socket_service.dart';
import '../domain/chat_message.dart';
import 'group_members_sheet.dart';

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
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
        _loadError = null;
      });
    }
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
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            tooltip: 'Group members',
            icon: const Icon(Icons.more_vert),
            onPressed: _showGroupMembers,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingHistory
                ? Center(
                    child: SketchBox(
                      radius: 18,
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            color: SketchColors.ink,
                            strokeWidth: 2,
                          ),
                          const SizedBox(height: 12),
                          const Text('Loading conversation...'),
                        ],
                      ),
                    ),
                  )
                : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SketchBox(
                        radius: 18,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.chat_bubble_outline, size: 34),
                            const SizedBox(height: 12),
                            Text(
                              'Could not load chat: $_loadError',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            SketchButton(
                              label: 'Retry',
                              icon: const Icon(Icons.refresh),
                              onPressed: _init,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: SketchBox(
                        radius: 18,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.forum_outlined, size: 36),
                            const SizedBox(height: 8),
                            Text(
                              'Start the conversation',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Send a message to your group.',
                              style: TextStyle(color: SketchColors.inkFaint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
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
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: SketchBox(
                              seed: message.id.hashCode,
                              radius: 16,
                              fill: isMine ? SketchColors.ink : null,
                              strokeColor: isMine ? SketchColors.ink : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (!isMine)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 3),
                                      child: Text(
                                        message.senderName,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: SketchColors.inkFaint,
                                        ),
                                      ),
                                    ),
                                  Text(
                                    message.content,
                                    style: TextStyle(
                                      color: isMine
                                          ? SketchColors.paper
                                          : SketchColors.ink,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          // Small, non-blocking strip -- never covers or disables the
          // input, and only appears after the debounce window above.
          if (_showConnectingBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: SketchBox(
                seed: 91,
                radius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: SketchColors.inkFaint,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reconnecting...',
                      style: TextStyle(
                        color: SketchColors.inkFaint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: SketchBox(
                seed: 92,
                radius: 18,
                padding: const EdgeInsets.fromLTRB(14, 4, 6, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: SketchColors.inkFaint),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SketchBox(
                      seed: 93,
                      radius: 13,
                      fill: SketchColors.ink,
                      padding: EdgeInsets.zero,
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: _send,
                          child: Padding(
                            padding: const EdgeInsets.all(11),
                            child: Icon(
                              Icons.send_rounded,
                              size: 20,
                              color: SketchColors.paper,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showGroupMembers() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => GroupMembersSheet(groupId: widget.groupId),
    );
  }
}
