// File: lib/screens/customer/chat_screen.dart
// *** UPDATED & FIXED FILE ***

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/input.dart';

// ChatMessage model remains the same
class ChatMessage {
  final String id;
  final String senderId;
  final String recipientId;
  final String message;
  final Timestamp timestamp;
  bool isReadByRecipient;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.message,
    required this.timestamp,
    this.isReadByRecipient = false,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      recipientId: data['recipientId'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isReadByRecipient: data['isReadByRecipient'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'recipientId': recipientId,
      'message': message,
      'timestamp': timestamp,
      'isReadByRecipient': isReadByRecipient,
    };
  }
}

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';
  final String orderId;
  final String currentUserId;
  final String recipientId;
  final String recipientName;
  final String? recipientPhotoUrl;
  final String? recipientPhoneNumber;

  // <<< FIX: ApiService instance is removed from the widget class >>>

  // <<< FIX: 'const' is removed from the constructor >>>
  const ChatScreen({
    super.key,
    required this.orderId,
    required this.currentUserId,
    required this.recipientId,
    required this.recipientName,
    this.recipientPhotoUrl,
    this.recipientPhoneNumber,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // <<< FIX: ApiService instance is correctly placed in the State class >>>
  final ApiService _apiService = ApiService();

  StreamSubscription<QuerySnapshot>? _messageSubscription;
  List<ChatMessage> _messages = [];
  bool _isLoadingInitialMessages = true;
  bool _isSending = false;

  late AnimationController _entryAnimController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _entryAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _entryAnimController, curve: Curves.easeIn));

    _loadMessages();
  }

  void _loadMessages() {
    final messagesRef = FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.orderId)
        .collection('messages')
        .orderBy('timestamp', descending: false);

    _messageSubscription = messagesRef.snapshots().listen((snapshot) {
      if (mounted) {
        final newMessages =
            snapshot.docs.map((doc) => ChatMessage.fromFirestore(doc)).toList();
        setState(() {
          _messages = newMessages;
          if (_isLoadingInitialMessages) _isLoadingInitialMessages = false;
        });
        if (!_isLoadingInitialMessages) _entryAnimController.forward(from: 0.0);
        _scrollToBottom(isNewMessage: true);
        _markMessagesAsRead(newMessages);
      }
    }, onError: (error) {
      print("Error listening to messages: $error");
      if (mounted) {
        setState(() {
          _isLoadingInitialMessages = false;
        });
        _showFeedbackSnackbar(
            "Error loading messages. Please check your connection.", context,
            isError: true);
      }
    });
  }

  void _markMessagesAsRead(List<ChatMessage> messages) {
    WriteBatch batch = FirebaseFirestore.instance.batch();
    bool needsCommit = false;
    for (var msg in messages) {
      if (msg.recipientId == widget.currentUserId && !msg.isReadByRecipient) {
        DocumentReference msgRef = FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.orderId)
            .collection('messages')
            .doc(msg.id);
        batch.update(msgRef, {'isReadByRecipient': true});
        needsCommit = true;
      }
    }
    if (needsCommit) {
      batch
          .commit()
          .catchError((e) => print("Error batch marking messages as read: $e"));
    }
  }

  void _scrollToBottom({bool isNewMessage = false}) {
    if (_scrollController.hasClients) {
      Future.delayed(Duration(milliseconds: isNewMessage ? 150 : 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() => _isSending = true);
    _messageController.clear();

    final messageData = {
      'senderId': widget.currentUserId,
      'recipientId': widget.recipientId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'isReadByRecipient': false,
    };

    try {
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.orderId)
          .collection('messages')
          .add(messageData);

      _scrollToBottom(isNewMessage: true);

      // Now this will work because _apiService is in the correct scope
      await _apiService.updateChatThread(
        chatId: widget.orderId,
        lastMessage: messageText,
        senderId: widget.currentUserId,
      );
    } catch (e) {
      print("Error sending message: $e");
      if (mounted) {
        _showFeedbackSnackbar(
            "Failed to send message. Please try again.", context,
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {ThemeProvider? themeProvider, bool isError = false}) {
    final tp = themeProvider ?? Provider.of<ThemeProvider>(ctx, listen: false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? tp.errorColor : tp.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  Future<void> _makePhoneCall(
      String? phoneNumber, ThemeProvider themeProvider) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      _showFeedbackSnackbar('Phone number not available.', context,
          themeProvider: themeProvider, isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        _showFeedbackSnackbar(
            'Could not launch phone dialer for $phoneNumber', context,
            themeProvider: themeProvider, isError: true);
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageSubscription?.cancel();
    _entryAnimController.dispose();
    super.dispose();
  }

  // The entire build method and its helpers remain unchanged from here on.
  // Omitting for brevity.
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: themeProvider.cardBackground,
        elevation: 1.0,
        shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: themeProvider.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            if (widget.recipientPhotoUrl != null &&
                widget.recipientPhotoUrl!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.recipientPhotoUrl!),
                backgroundColor: themeProvider.appSecondaryBackground,
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: themeProvider.gas2doorPrimaryBlueLightVer,
                child: Text(
                    widget.recipientName.isNotEmpty
                        ? widget.recipientName[0].toUpperCase()
                        : '?',
                    style: GoogleFonts.inter(
                        color: themeProvider.infoColorOnDarkBgs,
                        fontWeight: FontWeight.bold)),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.recipientName,
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 17),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (widget.recipientPhoneNumber != null &&
              widget.recipientPhoneNumber!.isNotEmpty)
            IconButton(
              icon: Icon(Icons.call_outlined,
                  color: themeProvider.gas2doorPrimaryBlue),
              onPressed: () =>
                  _makePhoneCall(widget.recipientPhoneNumber, themeProvider),
              tooltip: "Call ${widget.recipientName}",
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoadingInitialMessages
                ? Center(
                    child: CircularProgressIndicator(
                        color: themeProvider.gas2doorPrimaryBlue))
                : _messages.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded,
                                  size: 60,
                                  color: themeProvider.secondaryText
                                      .withOpacity(0.5)),
                              const SizedBox(height: 16),
                              Text('No messages yet.',
                                  style: GoogleFonts.inter(
                                      color: themeProvider.secondaryText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500)),
                              Text('Start the conversation!',
                                  style: GoogleFonts.inter(
                                      color: themeProvider.tertiaryText,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      )
                    : FadeTransition(
                        opacity: _entryAnimController,
                        child: ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10.0, vertical: 12.0),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final bool isMe =
                                message.senderId == widget.currentUserId;
                            return _buildChatBubble(
                                message, isMe, themeProvider);
                          },
                        ),
                      ),
          ),
          _buildMessageInputField(themeProvider),
        ],
      ),
    );
  }

  Widget _buildChatBubble(
      ChatMessage message, bool isMe, ThemeProvider themeProvider) {
    final alignment = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor =
        isMe ? themeProvider.gas2doorPrimaryBlue : themeProvider.cardBackground;
    final textColor =
        isMe ? themeProvider.infoColorOnDarkBgs : themeProvider.primaryText;
    final timestampColor = isMe
        ? themeProvider.infoColorOnDarkBgs.withOpacity(0.8)
        : themeProvider.tertiaryText;
    final bubbleRadius = Radius.circular(themeProvider.cardBorderRadiusValue);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: bubbleRadius,
                  topRight: bubbleRadius,
                  bottomLeft: isMe ? bubbleRadius : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : bubbleRadius,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        themeProvider.cardShadowColorGlobal.withOpacity(0.15),
                    blurRadius: 3,
                    offset: const Offset(1, 1),
                  )
                ]),
            padding:
                const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(
                  message.message,
                  style: GoogleFonts.inter(
                      color: textColor, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 5.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a')
                          .format(message.timestamp.toDate().toLocal()),
                      style: GoogleFonts.inter(
                          color: timestampColor, fontSize: 11),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 6),
                      Icon(
                        message.isReadByRecipient
                            ? Icons.done_all_rounded
                            : Icons.done_rounded,
                        color: message.isReadByRecipient
                            ? themeProvider.gas2doorTealLightVer
                            : timestampColor,
                        size: 15,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInputField(ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: themeProvider.cardBackground,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 5,
            color: themeProvider.cardShadowColorGlobal.withOpacity(0.08),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
          12.0, 10.0, 12.0, MediaQuery.of(context).padding.bottom + 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CustomInput(
              controller: _messageController,
              hintText: 'Type a message...',
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
              // To make CustomInput more compact for chat, you might need to adjust its internal contentPadding
              // or allow contentPadding to be passed as a parameter to CustomInput.
              // For now, it will use CustomInput's default padding.
            ),
          ),
          const SizedBox(width: 8), // Reduced space
          // --- CORRECTED Send Button using IconButton ---
          Material(
            color: themeProvider.gas2doorPrimaryBlue,
            borderRadius: BorderRadius.circular(25), // Circular shape
            elevation: 2.0, // Subtle elevation
            child: InkWell(
              onTap: _isSending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(25),
              splashColor:
                  themeProvider.gas2doorPrimaryBlueLightVer.withOpacity(0.5),
              highlightColor:
                  themeProvider.gas2doorPrimaryBlueLightVer.withOpacity(0.3),
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: _isSending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white))
                      : Icon(Icons.send_rounded,
                          color: themeProvider.infoColorOnDarkBgs, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
