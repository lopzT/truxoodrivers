import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

// ===== ENUMS =====
enum MessageType { text, image }
enum MessageStatus { sending, sent, delivered, failed, read }
enum ChatAction { clearChat, blockUser, reportUser }

// ===== MODELS =====
class ChatMessage {
  final String id;
  final String text;
  final bool isFromDriver;
  final DateTime timestamp;
  final MessageType type;
  final MessageStatus status;
  final DateTime? deliveredAt;
  final DateTime? readAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromDriver,
    required this.timestamp,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    this.deliveredAt,
    this.readAt,
  });

  bool get isSent =>
      status == MessageStatus.sent ||
      status == MessageStatus.delivered ||
      status == MessageStatus.read;
}

// ===== REPOSITORY =====
class ChatRepository {
  static final Map<String, List<ChatMessage>> _localStorage = {};

  Future<void> saveMessage(ChatMessage message, String conversationId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (!_localStorage.containsKey(conversationId)) {
      _localStorage[conversationId] = [];
    }
    _localStorage[conversationId]!.add(message);
  }

  Future<List<ChatMessage>> loadMessages(
    String conversationId, {
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));

    if (!_localStorage.containsKey(conversationId)) {
      return [];
    }

    final allMessages = _localStorage[conversationId]!;

    if (allMessages.length <= limit) {
      return List.from(allMessages);
    } else {
      return allMessages.sublist(allMessages.length - limit);
    }
  }

  Future<List<ChatMessage>> loadOlderMessages(
    String conversationId, {
    required DateTime beforeTimestamp,
    int limit = 20,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!_localStorage.containsKey(conversationId)) {
      return [];
    }

    final allMessages = _localStorage[conversationId]!;

    final olderMessages = allMessages
        .where((message) => message.timestamp.isBefore(beforeTimestamp))
        .toList();

    if (olderMessages.length <= limit) {
      return olderMessages;
    } else {
      return olderMessages.sublist(olderMessages.length - limit);
    }
  }

  Future<List<ChatMessage>> searchMessages(
    String conversationId,
    String query,
  ) async {
    if (!_localStorage.containsKey(conversationId)) {
      return [];
    }

    final messages = _localStorage[conversationId]!;
    return messages
        .where((msg) =>
            msg.text.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (_localStorage.containsKey(conversationId)) {
      _localStorage[conversationId]!
          .removeWhere((msg) => msg.id == messageId);
    }
  }
}

// ===== CHAT SCREEN =====
class ChatScreen extends StatefulWidget {
  final String clientName;
  final String clientPhone;

  const ChatScreen({
    super.key,
    required this.clientName,
    required this.clientPhone,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ChatRepository _repository = ChatRepository();
  final List<ChatMessage> _messages = [];

  bool _isClientOnline = true;
  bool _isClientTyping = false;
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
  bool _isConnected = true;
  final int _messagesPerPage = 20;

  late String _conversationId;

  @override
  void initState() {
    super.initState();
    _conversationId = 'driver_${widget.clientPhone}';
    BackButtonInterceptor.add(_backButtonInterceptor);
    _loadInitialMessages();
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(_backButtonInterceptor);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _backButtonInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    Navigator.of(context).pop();
    return true;
  }

  Future<void> _loadInitialMessages() async {
    try {
      final messages = await _repository.loadMessages(
        _conversationId,
        limit: _messagesPerPage,
      );

      if (!mounted) return;

      setState(() {
        _messages.addAll(messages);
      });

      if (messages.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Error loading initial messages: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading messages: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    setState(() => _isLoadingMore = true);

    try {
      final previousScrollHeight =
          _scrollController.position.maxScrollExtent;

      final olderMessages = await _repository.loadOlderMessages(
        _conversationId,
        beforeTimestamp: _messages.first.timestamp,
        limit: _messagesPerPage,
      );

      if (!mounted) return;

      setState(() {
        _messages.insertAll(0, olderMessages);
        _hasMoreMessages = olderMessages.length == _messagesPerPage;
      });

      // Preserve scroll position
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          final newScrollHeight =
              _scrollController.position.maxScrollExtent;
          final scrollDifference = newScrollHeight - previousScrollHeight;
          _scrollController.jumpTo(
            _scrollController.offset + scrollDifference,
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading older messages: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _sendMessage({MessageType type = MessageType.text}) async {
    String messageText = _messageController.text.trim();

    // ✅ Validation
    if (messageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message cannot be empty'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    if (messageText.length > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message is too long (max 500 characters)'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No internet connection'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      isFromDriver: true,
      timestamp: DateTime.now(),
      type: type,
      status: MessageStatus.sending,
    );

    try {
      // Optimistic UI update
      setState(() {
        _messages.add(message);
        _messageController.clear();
      });
      _scrollToBottom();

      // Save to backend
      await _repository.saveMessage(message, _conversationId);

      // Update status
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          _messages[index] = ChatMessage(
            id: message.id,
            text: message.text,
            isFromDriver: message.isFromDriver,
            timestamp: message.timestamp,
            type: message.type,
            status: MessageStatus.sent,
            deliveredAt: DateTime.now(),
          );
        }
      });

      HapticFeedback.lightImpact();
    } catch (e) {
      setState(() {
        _messages.remove(message);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);

      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch phone dialer'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error making call: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showMessageOptions(ChatMessage message) {
    if (!message.isFromDriver) return;

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message'),
              onTap: () {
                Navigator.pop(context);
                _deleteMessage(message);
              },
            ),
            ListTile(
              leading: const Icon(Icons.content_copy),
              title: const Text('Copy'),
              onTap: () {
                Clipboard.setData(ClipboardData(text: message.text));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteMessage(ChatMessage message) async {
    try {
      setState(() {
        _messages.remove(message);
      });

      await _repository.deleteMessage(_conversationId, message.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message deleted')),
        );
      }
    } catch (e) {
      setState(() {
        _messages.add(message);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('Are you sure you want to clear this chat?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() => _messages.clear());
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Chat cleared')),
              );
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _blockUser() async {
    try {
      // TODO: Call backend to block user
      debugPrint('User blocked: ${widget.clientName}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.clientName} blocked'),
            backgroundColor: Colors.red,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => true,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Row(
            children: [
              Stack(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white, size: 18),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isClientOnline ? Colors.green : Colors.grey,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.clientName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _isClientTyping
                          ? 'Typing...'
                          : (_isClientOnline
                              ? 'Online'
                              : 'Last seen recently'),
                      style: TextStyle(
                        fontSize: 12,
                        color: _isClientTyping
                            ? Colors.blue
                            : (_isClientOnline
                                ? Colors.green[300]
                                : Colors.grey[300]),
                        fontStyle: _isClientTyping
                            ? FontStyle.italic
                            : FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => _makePhoneCall(widget.clientPhone),
              icon: const Icon(Icons.phone),
              tooltip: 'Call ${widget.clientName}',
            ),
            PopupMenuButton<ChatAction>(
              onSelected: (action) {
                switch (action) {
                  case ChatAction.clearChat:
                    _showClearChatConfirmation();
                    break;
                  case ChatAction.blockUser:
                    _blockUser();
                    break;
                  case ChatAction.reportUser:
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${widget.clientName} reported')),
                    );
                    break;
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<ChatAction>(
                  value: ChatAction.clearChat,
                  child: Row(
                    children: [
                      Icon(Icons.clear_all, color: Colors.black),
                      SizedBox(width: 8),
                      Text('Clear Chat'),
                    ],
                  ),
                ),
                const PopupMenuItem<ChatAction>(
                  value: ChatAction.blockUser,
                  child: Row(
                    children: [
                      Icon(Icons.block, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Block User'),
                    ],
                  ),
                ),
                const PopupMenuItem<ChatAction>(
                  value: ChatAction.reportUser,
                  child: Row(
                    children: [
                      Icon(Icons.report, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Report User'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            // Connection status
            if (!_isConnected)
              Container(
                color: Colors.orange,
                padding: const EdgeInsets.all(8),
                child: const Text(
                  'No internet connection',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            // Messages
            Expanded(
              child: _messages.isEmpty
                  ? const Center(
                      child: Text(
                        'Start a conversation with your client',
                        style: TextStyle(fontSize: 16, color: Colors.grey),
                      ),
                    )
                  : _buildMessageList(),
            ),
            // Input
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      reverse: true,
      controller: _scrollController,
      itemCount: _messages.length + (_hasMoreMessages ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length) {
          return _buildLoadingIndicator();
        }

        if (index >= _messages.length - 5 &&
            !_isLoadingMore &&
            _hasMoreMessages) {
          _loadMoreMessages();
        }

        final reversedIndex = _messages.length - 1 - index;
        return GestureDetector(
          onLongPress: () =>
              _showMessageOptions(_messages[reversedIndex]),
          child: _buildMessageBubble(_messages[reversedIndex]),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.all(16.0),
      child: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: message.isFromDriver
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!message.isFromDriver) ...[
            const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, color: Colors.white, size: 12),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: message.isFromDriver ? Colors.black : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(
                    message.isFromDriver ? 20 : 5,
                  ),
                  bottomRight: Radius.circular(
                    message.isFromDriver ? 5 : 20,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isFromDriver
                          ? Colors.white
                          : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: message.isFromDriver
                              ? Colors.white70
                              : Colors.grey[600],
                        ),
                      ),
                      if (message.isFromDriver) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.status == MessageStatus.read
                              ? Icons.done_all
                              : Icons.done,
                          size: 14,
                          color: message.status == MessageStatus.read
                              ? Colors.blue
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (message.isFromDriver) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.black,
              child: Icon(Icons.local_shipping,
                  color: Colors.white, size: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: TextField(
                  controller: _messageController,
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  maxLines: null,
                  maxLength: 500,
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton(
              onPressed: () => _sendMessage(),
              backgroundColor: Colors.black,
              mini: true,
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final msgDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    final timeStr =
        '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    if (msgDate == today) {
      return timeStr;
    } else if (msgDate == yesterday) {
      return 'Yesterday $timeStr';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}