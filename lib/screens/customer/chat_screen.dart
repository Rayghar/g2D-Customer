// lib/screens/customer/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/theme_provider.dart';
import '../../services/api_service.dart';
import '../../services/socket_service.dart';
import '../../models/message.dart';
import '../../widgets/input.dart';

class ChatScreen extends StatefulWidget {
  static const String routeName = '/chat';

  /// Room id (== order UUID)
  final String chatId;

  /// Current user (customer) id
  final String currentUserId;

  /// Counterpart user id (driver) – UI only; server will validate recipient
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

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _api = ApiService();
  late final SocketService _socket;

  final List<Message> _messages = [];
  bool _loading = true;
  bool _sending = false;
  bool _refreshing = false;

  late final AnimationController _entryAnim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entryAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fade = CurvedAnimation(parent: _entryAnim, curve: Curves.easeIn);

    // defer so Provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _socket = Provider.of<SocketService>(context, listen: false);
      await _loadHistory();
      _connectAndListen();
      // Mark as read after we've joined/loaded
      _socket.markRead(widget.chatId);
    });
  }

  // ---------- Networking ----------

  Future<void> _loadHistory() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final history = await _api.getChatHistory(widget.chatId);
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(history);
        _loading = false;
      });
      _entryAnim.forward();
      _scrollToBottom();
    } catch (e) {
      debugPrint(
          '[ChatScreen] _loadHistory error: $e'); // 👈 see the real reason
      if (!mounted) return;
      setState(() => _loading = false);
      _snack('Error loading message history.', isError: true);
    }
  }

  void _connectAndListen() {
    _socket.connect();
    _socket.joinRoom(widget.chatId);

    // New incoming messages
    _socket.listenForMessage((data) {
      if (!mounted) return;
      final incoming = Message.fromJson(data);

      // Reconcile optimistic bubble sent by me (same text)
      final idx = _messages.lastIndexWhere((m) =>
          m.id.startsWith('temp_') &&
          m.senderId == widget.currentUserId &&
          m.text == incoming.text);

      setState(() {
        if (idx != -1) {
          _messages[idx] = incoming;
        } else if (!_messages.any((m) => m.id == incoming.id)) {
          _messages.add(incoming);
        }
      });
      _scrollToBottom(isNew: true);

      // Mark as read if it's not from me
      if (incoming.senderId != widget.currentUserId) {
        _socket.markRead(widget.chatId);
      }
    });

    // Server ack -> replace temp id with real id
    _socket.onAck((ack) {
      final String? tempId = ack?['tempId']?.toString();
      final String? realId = ack?['messageId']?.toString();
      if (tempId == null || realId == null) return;

      final i = _messages.indexWhere((m) => m.id == tempId);
      if (i != -1) {
        final m = _messages[i];
        setState(() {
          _messages[i] = _cloned(m, id: realId);
        });
      }
    });

    // Status updates (delivered/read)
    _socket.onStatus((payload) {
      final id = payload?['messageId']?.toString();
      final status = payload?['status']?.toString();
      if (id == null || status == null) return;

      final i = _messages.indexWhere((m) => m.id == id);
      if (i != -1) {
        final m = _messages[i];
        setState(() => _messages[i] = _cloned(m, status: status));
      }
    });

    // Entire chat marked read
    _socket.onChatRead((payload) {
      final chatId = payload?['chatId']?.toString();
      if (chatId != widget.chatId) return;
      setState(() {
        for (var i = 0; i < _messages.length; i++) {
          final m = _messages[i];
          final mine = m.senderId == widget.currentUserId;
          final needsUpdate =
              m.status == null || m.status == 'sent' || m.status == 'delivered';
          if (mine && needsUpdate) {
            _messages[i] = _cloned(m, status: 'read');
          }
        }
      });
    });

    // Surface socket errors
    _socket.onErrorEvt((err) {
      final msg = (err is Map && err['message'] != null)
          ? err['message'].toString()
          : 'Chat error';
      _snack(msg, isError: true);
    });
  }

  // Send message (optimistic)
  void _sendMessage() {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _sending) return;

    HapticFeedback.mediumImpact();
    setState(() => _sending = true);

    final tempId = 'temp_${DateTime.now().microsecondsSinceEpoch}';
    final optimistic = Message(
      id: tempId,
      chatId: widget.chatId,
      senderId: widget.currentUserId,
      recipientId: widget.recipientId,
      text: text,
      status: 'sent',
      createdAt: DateTime.now().toUtc(),
    );

    setState(() {
      _messages.add(optimistic);
      _msgCtrl.clear();
    });
    _scrollToBottom(isNew: true);

    _socket.sendMessage(
      chatId: widget.chatId,
      recipientId: widget.recipientId,
      text: text,
      tempId: tempId,
    );

    if (mounted) setState(() => _sending = false);
  }

  // ---------- UI helpers ----------

  Message _cloned(Message m, {String? id, String? status}) {
    return Message(
      id: id ?? m.id,
      chatId: m.chatId,
      senderId: m.senderId,
      recipientId: m.recipientId,
      text: m.text,
      createdAt: m.createdAt,
      status: status ?? m.status,
    );
  }

  void _scrollToBottom({bool isNew = false}) {
    if (!_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: Duration(milliseconds: isNew ? 300 : 150),
        curve: Curves.easeOutCubic,
      );
    });
  }

  void _snack(String msg, {bool isError = false}) {
    final tp = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor:
            isError ? tp.errorColor : tp.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  Future<void> _call(String? phone, ThemeProvider theme) async {
    if (phone == null || phone.isEmpty) {
      _snack('Phone number not available.', isError: true);
      return;
    }
    HapticFeedback.mediumImpact();
    final uri = Uri(scheme: 'tel', path: phone);
    if (!await canLaunchUrl(uri) || !await launchUrl(uri)) {
      _snack('Could not launch phone dialer for $phone', isError: true);
    }
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    await _loadHistory();
    if (mounted) setState(() => _refreshing = false);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _entryAnim.dispose();
    // keep socket alive app-wide, but remove listeners for this screen
    //_socket.removeAllListeners();
    super.dispose();
  }

  // ---------- BUILD ----------

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.appSecondaryBackground,
      appBar: AppBar(
        backgroundColor: theme.cardBackground,
        elevation: 1,
        shadowColor: theme.cardShadowColorGlobal.withOpacity(0.3),
        leading: IconButton(
          icon:
              Icon(Icons.arrow_back_ios_new_rounded, color: theme.primaryText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            if (widget.recipientPhotoUrl != null &&
                widget.recipientPhotoUrl!.isNotEmpty)
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(widget.recipientPhotoUrl!),
                backgroundColor: theme.appSecondaryBackground,
              )
            else
              CircleAvatar(
                radius: 18,
                backgroundColor: theme.gas2doorPrimaryBlueLightVer,
                child: Text(
                  widget.recipientName.isNotEmpty
                      ? widget.recipientName[0].toUpperCase()
                      : '?',
                  style: GoogleFonts.inter(
                    color: theme.infoColorOnDarkBgs,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.recipientName,
                style: GoogleFonts.inter(
                  color: theme.primaryText,
                  fontWeight: FontWeight.w600,
                  fontSize: 17,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (widget.recipientPhoneNumber != null &&
                widget.recipientPhoneNumber!.isNotEmpty)
              IconButton(
                icon:
                    Icon(Icons.call_outlined, color: theme.gas2doorPrimaryBlue),
                onPressed: () => _call(widget.recipientPhoneNumber, theme),
                tooltip: "Call ${widget.recipientName}",
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? Center(
                    child: CircularProgressIndicator(
                        color: theme.gas2doorPrimaryBlue),
                  )
                : RefreshIndicator(
                    onRefresh: _refresh,
                    child: _messages.isEmpty
                        ? _empty(theme)
                        : FadeTransition(
                            opacity: _fade,
                            child: ListView.builder(
                              controller: _scrollCtrl,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 12),
                              itemCount: _messages.length,
                              itemBuilder: (context, i) {
                                final m = _messages[i];
                                final isMe = m.senderId == widget.currentUserId;
                                return _bubble(m, isMe, theme);
                              },
                            ),
                          ),
                  ),
          ),
          _input(theme),
        ],
      ),
    );
  }

  Widget _empty(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
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
      ),
    );
  }

  Widget _bubble(Message m, bool isMe, ThemeProvider theme) {
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bubbleColor = isMe ? theme.gas2doorPrimaryBlue : theme.cardBackground;
    final textColor = isMe ? theme.infoColorOnDarkBgs : theme.primaryText;
    final timeColor =
        isMe ? theme.infoColorOnDarkBgs.withOpacity(0.8) : theme.tertiaryText;
    final r = Radius.circular(theme.cardBorderRadiusValue);

    Widget? receiptIcon() {
      if (!isMe) return null;
      switch (m.status) {
        case 'read':
          return const Icon(Icons.done_all, size: 14);
        case 'delivered':
          return const Icon(Icons.done_all, size: 14);
        default:
          return const Icon(Icons.check, size: 14);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: r,
                topRight: r,
                bottomLeft: isMe ? r : const Radius.circular(4),
                bottomRight: isMe ? const Radius.circular(4) : r,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.cardShadowColorGlobal.withOpacity(0.15),
                  blurRadius: 3,
                  offset: const Offset(1, 1),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Text(m.text,
                    style: GoogleFonts.inter(
                        color: textColor, fontSize: 15, height: 1.35)),
                const SizedBox(height: 5),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('hh:mm a').format(m.createdAt.toLocal()),
                      style: GoogleFonts.inter(color: timeColor, fontSize: 11),
                    ),
                    finalReceipt(timeColor, receiptIcon()),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget finalReceipt(Color timeColor, Widget? icon) {
    if (icon == null) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(width: 6),
        IconTheme.merge(
          data: IconThemeData(color: timeColor, size: 13),
          child: icon,
        ),
      ],
    );
  }

  Widget _input(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardBackground,
        boxShadow: [
          BoxShadow(
            offset: const Offset(0, -2),
            blurRadius: 5,
            color: theme.cardShadowColorGlobal.withOpacity(0.08),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        12,
        10,
        12,
        MediaQuery.of(context).padding.bottom + 10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: CustomInput(
              controller: _msgCtrl,
              hintText: 'Type a message…',
              keyboardType: TextInputType.multiline,
              maxLines: 5,
              minLines: 1,
              textInputAction: TextInputAction.newline,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: theme.gas2doorPrimaryBlue,
            borderRadius: BorderRadius.circular(25),
            elevation: 2,
            child: InkWell(
              onTap: _sending ? null : _sendMessage,
              borderRadius: BorderRadius.circular(25),
              splashColor: theme.gas2doorPrimaryBlueLightVer.withOpacity(0.5),
              highlightColor:
                  theme.gas2doorPrimaryBlueLightVer.withOpacity(0.3),
              child: SizedBox(
                width: 50,
                height: 50,
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded,
                          color: Colors.white, size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
