// File: lib/services/agent_referral_handler.dart
import 'package:flutter/foundation.dart';

/// A simple static class to handle and temporarily store an agent referral code
/// captured from a Firebase Dynamic Link.
class AgentReferralHandler {
  // A private static variable to hold the code.
  static String? _agentCode;

  /// Retrieves the captured agent code.
  /// This is called by the registration screen to pre-fill the code.
  static String? getAgentCode() {
    return _agentCode;
  }

  /// Processes the deep link URI to extract and store the agent code.
  /// This is called from main.dart when a dynamic link is received.
  /// The link is expected to look like: .../register?agentCode=AGENTX
  static void handleLink(Uri deepLink) {
    final agentCode = deepLink.queryParameters['agentCode'];
    if (agentCode != null && agentCode.isNotEmpty) {
      _agentCode = agentCode;
      if (kDebugMode) {
        print('Agent referral code captured from dynamic link: $_agentCode');
      }
    }
  }

  /// Clears the stored agent code.
  /// This should be called after the code has been successfully used during registration
  /// to prevent it from being accidentally used again.
  static void clearAgentCode() {
    _agentCode = null;
  }
}
