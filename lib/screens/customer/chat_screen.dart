// lib/screens/customer/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../models/message.dart';
import '../../widgets/input.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  final String chatId;
  final String currentUserId;
  final String recipientId;
  final String recipientName;
  final String? recipientPhotoUrl;
  final String? recipientPhoneNumber;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientName,
    this.recipientPhotoUrl,
    this.recipientPhoneNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = ApiService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initRealtime());
  }

  Future<void> _initRealtime() async {
    if (!mounted) return;
    final socket = context.read<SocketService>();
    await socket.joinChat(widget.chatId);

    await _refreshMessages();

    if (mounted) {
      setState(() => _isLoading = false);
      socket.markRead(widget.chatId);
    }
  }

  Future<void> _refreshMessages() async {
    try {
      final history = await _api.getChatHistory(widget.chatId);
      if (mounted) {
        context.read<SocketService>().seedHistory(widget.chatId, history);
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[ChatScreen] Failed to load history: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to load message history.")));
      }
    }
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<SocketService>().markRead(widget.chatId);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onSend() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    context.read<SocketService>().sendMessage(
          chatId: widget.chatId,
          text: text,
          senderId: widget.currentUserId,
          recipientId: widget.recipientId,
        );
    _msgCtrl.clear();
    _scrollToBottom(animated: true);
  }

  Future<void> _callRecipient() async {
    if (widget.recipientPhoneNumber == null) return;
    final url = Uri.parse('tel:${widget.recipientPhoneNumber}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final socket = context.watch<SocketService>();
    final messages = socket.messagesFor(widget.chatId);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipientName,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        backgroundColor: theme.appPrimaryBackground,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.phone_rounded, color: theme.gas2doorPrimaryBlue),
            onPressed: _callRecipient,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const _EmptyState()
                    : RefreshIndicator(
                        onRefresh: _refreshMessages,
                        child: ListView.builder(
                          controller: _scrollCtrl,
                          padding: const EdgeInsets.all(8.0),
                          itemCount: messages.length,
                          itemBuilder: (ctx, i) =>
                              _buildMessageBubble(messages[i], theme),
                        ),
                      ),
          ),
          _InputBar(controller: _msgCtrl, onSend: _onSend),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message msg, ThemeProvider theme) {
    final isMine = msg.senderId == widget.currentUserId;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4.0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine
              ? theme.gas2doorPrimaryBlue
              : theme.cardBackground.withOpacity(0.8),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              msg.text,
              style: GoogleFonts.inter(
                  color: isMine ? Colors.white : theme.primaryText,
                  fontSize: 15),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  DateFormat('h:mm a').format(msg.createdAt.toLocal()),
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isMine
                          ? Colors.white.withOpacity(0.7)
                          : theme.tertiaryText),
                ),
                if (isMine) ...[
                  const SizedBox(width: 4),
                  _getStatusIcon(msg.status),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Icon _getStatusIcon(String? status) {
    IconData icon;
    Color color = Colors.grey;
    switch (status) {
      case 'sending':
        icon = Icons.access_time_rounded;
        break;
      case 'sent':
        icon = Icons.check_rounded;
        break;
      case 'delivered':
        icon = Icons.done_all_rounded;
        break;
      case 'read':
        icon = Icons.done_all_rounded;
        color = Colors.lightBlueAccent;
        break;
      default:
        icon = Icons.check_rounded;
    }
    return Icon(icon, size: 16, color: color);
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;

  const _InputBar({required this.controller, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: theme.cardBackground,
          border: Border(
              top: BorderSide(
                  color: theme.tertiaryText.withOpacity(0.2), width: 0.5)),
        ),
        child: Row(
          children: [
            Expanded(
              child: CustomInput(
                controller: controller,
                hintText: 'Type a message…',
                keyboardType: TextInputType.multiline,
                minLines: 1,
                maxLines: 5,
              ),
            ),
            IconButton(
              icon: Icon(Icons.send_rounded, color: theme.gas2doorPrimaryBlue),
              onPressed: onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 60, color: theme.secondaryText.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No messages yet.',
              style: GoogleFonts.inter(
                  color: theme.secondaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          Text('Start the conversation!',
              style:
                  GoogleFonts.inter(color: theme.tertiaryText, fontSize: 14)),
        ],
      ),
    );
  }
}
