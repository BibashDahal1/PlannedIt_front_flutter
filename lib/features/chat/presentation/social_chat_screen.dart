import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/sketch_colors.dart';
import '../../../core/widgets/sketch_box.dart';
import '../../../core/widgets/sketch_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../groups/data/social_groups_providers.dart';
import '../../groups/domain/social_group.dart';
import '../../groups/presentation/social_group_member_tile.dart';
import '../data/chat_providers.dart';
import '../data/social_chat_socket_service.dart';
import '../domain/chat_message.dart';

/// Chat for a social group (created by members, not tied to an activity).
/// Mirrors ChatScreen's behaviour; only the data source differs.
class SocialChatScreen extends ConsumerStatefulWidget {
  final String groupId;
  const SocialChatScreen({super.key, required this.groupId});

  @override
  ConsumerState<SocialChatScreen> createState() => _SocialChatScreenState();
}

class _SocialChatScreenState extends ConsumerState<SocialChatScreen> {
  SocialChatSocketService? _socketService;
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<ChatMessage>? _messageSubscription;
  StreamSubscription<void>? _removedSubscription;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  final Set<String> _messageIds = {};
  final List<String> _pendingMessages = [];

  bool _isLoadingHistory = true;
  bool _isSocketReady = false;
  bool _showConnectingBanner = false; // debounced: only after a sustained drop
  Timer? _connectingBannerDebounce;
  String? _loadError;
  bool _isActive = true;
  bool _isInitializing = false;

  @override
  void initState() {
    super.initState();
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
          .fetchSocialMessages(widget.groupId);
      if (!mounted || !_isActive) return;
      setState(() {
        _mergeMessages(history);
        _isLoadingHistory = false;
      });
      _scrollToBottom();

      final service = SocialChatSocketService(
        socialGroupId: widget.groupId,
        chatApi: ref.read(chatApiProvider),
      );
      _socketService = service;
      _listenToSocket(service);

      await service.connect();
    } catch (e) {
      if (!mounted || !_isActive) return;
      setState(() {
        _isLoadingHistory = false;
        _loadError = extractApiErrorMessage(e);
      });
    } finally {
      _isInitializing = false;
    }
  }

  void _listenToSocket(SocialChatSocketService service) {
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _removedSubscription?.cancel();
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

    // The admin removed this person: leave and refresh membership.
    _removedSubscription = service.removed.listen((_) {
      ref.invalidate(mySocialGroupsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are no longer in this group.')),
      );
      if (context.canPop()) context.pop();
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
    _removedSubscription?.cancel();
    _connectionSubscription = null;
    _messageSubscription = null;
    _removedSubscription = null;
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

  /// Input stays enabled: if the socket is mid-reconnect, the message is
  /// queued and flushed automatically once the connection is back.
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
    _connectingBannerDebounce?.cancel();
    _connectionSubscription?.cancel();
    _messageSubscription?.cancel();
    _removedSubscription?.cancel();
    _socketService?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  SocialGroup? _group() {
    final groups = ref.watch(mySocialGroupsProvider).value;
    if (groups == null) return null;
    for (final g in groups) {
      if (g.id == widget.groupId) return g;
    }
    return null;
  }

  void _showMembers(SocialGroup group) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: group.members.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) =>
                        SocialGroupMemberTile(member: group.members[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = ref.watch(authControllerProvider).value?.user?.id;
    final group = _group();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(group?.name ?? 'Group chat'),
        actions: [
          IconButton(
            tooltip: 'Group members',
            icon: const Icon(Icons.more_vert),
            onPressed: group == null ? null : () => _showMembers(group),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildBody(currentUserId)),
          // Small, non-blocking strip: never covers or disables the input,
          // and only appears after the debounce window above.
          if (_showConnectingBanner)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
              child: SketchBox(
                seed: 191,
                radius: 12,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
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
                    // Debug builds only: shows why the connection fails.
                    if (kDebugMode && _socketService?.lastError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _socketService!.lastError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: SketchColors.inkFaint,
                            fontSize: 10,
                          ),
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
                seed: 192,
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
                      seed: 193,
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

  Widget _buildBody(String? currentUserId) {
    if (_isLoadingHistory) {
      return Center(
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
      );
    }
    if (_loadError != null) {
      return Center(
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
      );
    }
    if (_messages.isEmpty) {
      return Center(
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
      );
    }
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _messages.length,
      itemBuilder: (context, i) {
        final message = _messages[i];
        final isMine = message.senderId == currentUserId;
        return Align(
          alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
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
                        color: isMine ? SketchColors.paper : SketchColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
