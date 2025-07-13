// File: lib/screens/driver/driver_messages_list_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // For DateFormat

import '../../providers/theme_provider.dart';
import '../../widgets/card.dart'; // Reusing CustomCard
import '../../widgets/button.dart'; // For Retry/Empty state
import '../customer/chat_screen.dart'; // Import the shared ChatScreen

// Mock Chat Thread Model
class ChatThread {
  final String orderId;
  final String customerId;
  final String customerName;
  final String? customerPhotoUrl;
  final String lastMessageSnippet;
  final DateTime lastMessageTime;
  final bool hasUnreadMessages;
  final String? customerPhoneNumber;

  ChatThread({
    required this.orderId,
    required this.customerId,
    required this.customerName,
    this.customerPhotoUrl,
    required this.lastMessageSnippet,
    required this.lastMessageTime,
    this.hasUnreadMessages = false,
    this.customerPhoneNumber,
  });
}

class DriverMessagesListScreen extends StatefulWidget {
  final String currentUserId; // Driver ID

  const DriverMessagesListScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<DriverMessagesListScreen> createState() =>
      _DriverMessagesListScreenState();
}

class _DriverMessagesListScreenState extends State<DriverMessagesListScreen>
    with TickerProviderStateMixin {
  bool _isLoadingChatThreads = true;
  List<ChatThread> _chatThreads = [];
  String? _errorMessage;

  late AnimationController _listAnimationController;

  @override
  void initState() {
    super.initState();
    _listAnimationController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fetchChatThreads();
  }

  @override
  void dispose() {
    _listAnimationController.dispose();
    super.dispose();
  }

  Future<void> _fetchChatThreads({bool isRefresh = false}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingChatThreads = true;
      if (isRefresh) _errorMessage = null;
    });

    // Simulate fetching chat threads
    await Future.delayed(Duration(milliseconds: isRefresh ? 400 : 900));

    if (mounted) {
      setState(() {
        _chatThreads = [
          ChatThread(
            orderId: "ORDCUST01",
            customerId: "custABC",
            customerName: "Ada Eze",
            customerPhoneNumber: "08011112222",
            lastMessageSnippet: "Okay, I'll be there in 5 minutes.",
            lastMessageTime:
                DateTime.now().subtract(const Duration(minutes: 5)),
            hasUnreadMessages: true,
          ),
          ChatThread(
            orderId: "ORDCUST04",
            customerId: "custDEF",
            customerName: "Bola Ahmed",
            customerPhoneNumber: "08033334444",
            lastMessageSnippet: "Driver is outside.",
            lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
            hasUnreadMessages: false,
          ),
          ChatThread(
            orderId: "ORDCUST06",
            customerId: "custJKL",
            customerName: "Emeka Obi",
            customerPhoneNumber: "08077778888",
            lastMessageSnippet: "Thanks for the quick delivery!",
            lastMessageTime: DateTime.now().subtract(const Duration(days: 1)),
            hasUnreadMessages: false,
          ),
        ];
        _isLoadingChatThreads = false;
        // _errorMessage = "Simulated error loading chats."; // Test error state
      });
      if (_chatThreads.isNotEmpty && !_isLoadingChatThreads) {
        _listAnimationController.forward(from: 0.0);
      }
    }
  }

  void _navigateToChat(ChatThread thread, ThemeProvider themeProvider) {
    HapticFeedback.lightImpact();
    // Mark as read optimistically or after navigation if backend confirmation is slow
    final index = _chatThreads.indexWhere((t) =>
        t.orderId == thread.orderId && t.customerId == thread.customerId);
    if (index != -1 && _chatThreads[index].hasUnreadMessages && mounted) {
      // TODO: Call backend to mark as read
      // For UI, update immediately:
      // setState(() => _chatThreads[index].hasUnreadMessages = false); // This requires ChatThread.hasUnreadMessages to be non-final or use a copyWith
    }

    Navigator.pushNamed(context, ChatScreen.routeName, arguments: {
      'orderId': thread.orderId,
      'currentUserId': widget.currentUserId,
      'recipientId': thread.customerId,
      'recipientName': thread.customerName,
      'recipientPhoneNumber': thread.customerPhoneNumber,
      'recipientPhotoUrl': thread.customerPhotoUrl,
    }).then((_) {
      // Optionally refresh or update read status when returning from chat
      _fetchChatThreads(isRefresh: true); // Simple refresh
    });
  }

  void _showFeedbackSnackbar(String message, BuildContext ctx,
      {bool isError = false}) {
    if (!mounted) return;
    final themeProvider = Provider.of<ThemeProvider>(ctx, listen: false);
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? themeProvider.errorColor
            : themeProvider.successColor.withOpacity(0.95),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(12),
        elevation: 6,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final Color driverAccentColor = themeProvider.gas2doorTeal;

    return Scaffold(
      // Added Scaffold
      backgroundColor: themeProvider.appSecondaryBackground,
      body: RefreshIndicator(
        onRefresh: () => _fetchChatThreads(isRefresh: true),
        color: driverAccentColor,
        backgroundColor: themeProvider.cardBackground,
        child: _isLoadingChatThreads && _chatThreads.isEmpty
            ? _buildLoadingShimmer(themeProvider)
            : _errorMessage != null
                ? _buildErrorState(themeProvider, _errorMessage!)
                : _chatThreads.isEmpty
                    ? _buildEmptyState(
                        themeProvider, "You have no messages yet.")
                    : ListView.separated(
                        padding:
                            const EdgeInsets.all(12.0), // Consistent padding
                        itemCount: _chatThreads.length,
                        itemBuilder: (context, index) {
                          final itemAnimation = Tween<Offset>(
                                  begin: const Offset(0, 0.2), end: Offset.zero)
                              .animate(CurvedAnimation(
                                  parent: _listAnimationController,
                                  curve: Interval((0.1 * index).clamp(0.0, 1.0),
                                      (0.6 + 0.1 * index).clamp(0.0, 1.0),
                                      curve: Curves.easeOutCubic)));
                          return FadeTransition(
                            opacity: _listAnimationController,
                            child: SlideTransition(
                              position: itemAnimation,
                              child: _buildChatThreadItem(_chatThreads[index],
                                  themeProvider, driverAccentColor),
                            ),
                          );
                        },
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 8), // Consistent spacing
                      ),
      ),
    );
  }

  Widget _buildChatThreadItem(
      ChatThread thread, ThemeProvider themeProvider, Color driverAccentColor) {
    return CustomCard(
      // Standardized Card
      color: themeProvider.cardBackground,
      borderRadius: themeProvider.cardBorderRadiusValue,
      elevation: 1.5, // Subtle elevation
      shadowColor: themeProvider.cardShadowColorGlobal.withOpacity(0.3),
      margin: const EdgeInsets.only(
          bottom: 0), // Let ListView.separated handle spacing
      child: InkWell(
        onTap: () => _navigateToChat(thread, themeProvider),
        borderRadius: themeProvider.cardBorderRadius, // Match card radius
        splashColor: driverAccentColor.withOpacity(0.1),
        highlightColor: driverAccentColor.withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16.0, vertical: 12.0), // Consistent padding
          child: Row(
            children: [
              CircleAvatar(
                radius: 24, // Consistent avatar size
                backgroundColor:
                    driverAccentColor.withOpacity(0.15), // Themed background
                // backgroundImage: thread.customerPhotoUrl != null ? NetworkImage(thread.customerPhotoUrl!) : null, // Uncomment if photoUrl is used
                child: /* thread.customerPhotoUrl == null ? */ Text(
                    thread.customerName.isNotEmpty
                        ? thread.customerName[0].toUpperCase()
                        : 'C',
                    style: GoogleFonts.inter(
                        color: driverAccentColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18)) /* : null */,
              ),
              const SizedBox(width: 12), // Consistent spacing
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(thread.customerName,
                        style: GoogleFonts.inter(
                            // Consistent Typography
                            fontSize: 15.5, // Adjusted size
                            fontWeight: thread.hasUnreadMessages
                                ? FontWeight.bold
                                : FontWeight.w600, // Bold if unread
                            color: themeProvider.primaryText),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4), // Consistent spacing
                    Text(thread.lastMessageSnippet,
                        style: GoogleFonts.inter(
                          // Consistent Typography
                          fontSize: 13.5, // Adjusted size
                          color: thread.hasUnreadMessages
                              ? themeProvider.primaryText.withOpacity(0.9)
                              : themeProvider.secondaryText,
                          fontWeight: thread.hasUnreadMessages
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1),
                  ],
                ),
              ),
              const SizedBox(width: 8), // Consistent spacing
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment:
                    MainAxisAlignment.center, // Align time and dot
                children: [
                  Text(
                      DateFormat('h:mm a').format(thread.lastMessageTime
                          .toLocal()), // Consistent time format
                      style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: themeProvider.tertiaryText)), // Adjusted size
                  if (thread.hasUnreadMessages) ...[
                    const SizedBox(height: 5), // Consistent spacing
                    Container(
                      padding: const EdgeInsets.all(5), // Adjusted size
                      decoration: BoxDecoration(
                        color:
                            driverAccentColor, // Driver accent for unread dot
                        shape: BoxShape.circle,
                      ),
                      // child: Text('!', style: GoogleFonts.inter(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)), // Can show count or just a dot
                    ),
                  ],
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingShimmer(ThemeProvider themeProvider) {
    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: 5, // Number of shimmer items
      itemBuilder: (context, index) {
        return CustomCard(
          // Standardized Card for shimmer
          margin: const EdgeInsets.only(bottom: 12.0),
          color: themeProvider.cardBackground,
          borderRadius: themeProvider.cardBorderRadiusValue,
          elevation: 1.0,
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Row(
              children: [
                CircleAvatar(
                    radius: 24,
                    backgroundColor: themeProvider.shimmerBaseColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 120,
                          height: 16,
                          color: themeProvider.shimmerBaseColor,
                          margin: const EdgeInsets.only(bottom: 6)),
                      Container(
                          width: 180,
                          height: 14,
                          color: themeProvider.shimmerBaseColor),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                    width: 40,
                    height: 12,
                    color: themeProvider.shimmerBaseColor),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mark_chat_read_outlined,
                color: themeProvider.errorColor, size: 50), // Themed icon
            const SizedBox(height: 16),
            Text('Error Loading Messages',
                style: GoogleFonts.inter(
                    color: themeProvider.primaryText,
                    fontWeight: FontWeight.w600,
                    fontSize: 17)),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.inter(
                  color: themeProvider.secondaryText, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            CustomButton(
              // Standardized Button
              text: "Retry",
              onPressed: () => _fetchChatThreads(isRefresh: true),
              color:
                  themeProvider.gas2doorPrimaryBlue, // Consistent action color
              textStyle: GoogleFonts.inter(
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white,
                  fontWeight: FontWeight.w600),
              icon: Icon(Icons.refresh_rounded,
                  color: themeProvider.infoColorOnDarkBgs ?? Colors.white),
              height: 48, // Consistent height
              borderRadius: themeProvider.cardBorderRadiusValue,
            )
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeProvider themeProvider, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded,
                color: themeProvider.secondaryText.withOpacity(0.5),
                size: 60), // Adjusted size
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 17, // Adjusted size
                  fontWeight: FontWeight.w500,
                  color: themeProvider.primaryText),
            ),
            const SizedBox(height: 10), // Consistent spacing
            Text(
              'Chats with customers regarding their orders will appear here.', // Updated empty state message
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: themeProvider.secondaryText
                      .withOpacity(0.9)), // Adjusted size
            ),
          ],
        ),
      ),
    );
  }
}
