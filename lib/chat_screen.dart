import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

class ChatMessage {
  final String id;
  final String text;
  final bool isFromDriver;
  final DateTime timestamp;
  final MessageType type;

  ChatMessage({
    required this.id,
    required this.text,
    required this.isFromDriver,
    required this.timestamp,
    this.type = MessageType.text,
  });
}

enum MessageType { text, image }

class ChatRepository {
  static final Map<String, List<ChatMessage>> _localStorage = {};
  
  Future<void> saveMessage(ChatMessage message, String conversationId) async {

    await Future.delayed(const Duration(milliseconds: 100));
    
    if (!_localStorage.containsKey(conversationId)) {
      _localStorage[conversationId] = [];
    }
    _localStorage[conversationId]!.add(message);
  }
  
  Future<List<ChatMessage>> loadMessages(String conversationId, {int limit = 20}) async {
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
  
  Future<List<ChatMessage>> loadOlderMessages(String conversationId, {
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
}

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
  bool _isLoadingMore = false;
  bool _hasMoreMessages = true;
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
    final messages = await _repository.loadMessages(_conversationId, limit: _messagesPerPage);
    
    setState(() {
      _messages.addAll(messages);
    });
    
    if (messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;
    
    setState(() {
      _isLoadingMore = true;
    });

    final olderMessages = await _repository.loadOlderMessages(
      _conversationId,
      beforeTimestamp: _messages.first.timestamp,
      limit: _messagesPerPage,
    );

    setState(() {
      _messages.insertAll(0, olderMessages);
      _isLoadingMore = false;
      _hasMoreMessages = olderMessages.length == _messagesPerPage;
    });
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

        if (index >= _messages.length - 5 && !_isLoadingMore && _hasMoreMessages) {
          _loadMoreMessages();
        }
        
        final reversedIndex = _messages.length - 1 - index;
        return _buildMessageBubble(_messages[reversedIndex]);
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

  Future<void> _sendMessage({MessageType type = MessageType.text}) async {
    String messageText = _messageController.text.trim();
    
    if (messageText.isEmpty) return;

    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      isFromDriver: true,
      timestamp: DateTime.now(),
      type: type,
    );

    await _repository.saveMessage(message, _conversationId);

    setState(() {
      _messages.add(message);
      _messageController.clear();
    });

    _scrollToBottom();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _isClientOnline ? 'Online' : 'Last seen recently',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isClientOnline ? Colors.green[300] : Colors.grey[300],
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
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'block':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.clientName} blocked')),
                  );
                  break;
                case 'report':
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${widget.clientName} reported')),
                  );
                  break;
                case 'clear':
                  setState(() {
                    _messages.clear();
                  });
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.clear_all, color: Colors.black),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Block User'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.report, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Report User'),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? const Center(
                    child: Text(
                      'Start a conversation with your client',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : _buildMessageList(),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
                color: message.isFromDriver 
                    ? Colors.black 
                    : Colors.grey[200],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(message.isFromDriver ? 20 : 5),
                  bottomRight: Radius.circular(message.isFromDriver ? 5 : 20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isFromDriver ? Colors.white : Colors.black,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(message.timestamp),
                    style: TextStyle(
                      fontSize: 11,
                      color: message.isFromDriver 
                          ? Colors.white70 
                          : Colors.grey[600],
                    ),
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
              child: Icon(Icons.local_shipping, color: Colors.white, size: 12),
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
    final difference = now.difference(timestamp);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'now';
    }
  }
}
//ready