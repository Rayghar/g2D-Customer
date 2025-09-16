// File: lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../utils/constants.dart';
import '../models/feedback.dart' as app_feedback;
import '../models/location.dart' as app_location;
import '../models/notification.dart';
import '../models/user.dart' as app_user;
import '../models/address_model.dart';
import '../models/system_config_model.dart';
import '../models/admin/admin_config_model.dart' as admin_model;
import '../models/place_order_response_model.dart';
import '../models/order.dart' as app_order;
import '../models/deal_model.dart';
import '../models/chat_thread_model.dart';
import '../models/driver_stats_model.dart';
import '../models/driver_profile_model.dart';
import '../models/admin/dashboard_stats_model.dart';
import '../models/admin/admin_customer_summary_model.dart';
import '../models/admin/admin_driver_summary_model.dart';
import '../models/admin/admin_order_summary_model.dart';
import '../models/admin/admin_order_detail_model.dart';
import '../models/admin/admin_run_management_model.dart' as admin_run_models;
import '../models/admin/admin_driver_detail_model.dart';
import '../models/admin/admin_customer_detail_model.dart';
import '../models/admin/admin_promotion_model.dart';
import '../models/referral_model.dart';
import '../models/wallet_transaction.dart';
import '../models/admin/admin_referral_summary_model.dart';
import '../models/payment_method_model.dart';
import '../models/message.dart'; // You will need to create this simple model

import '../models/customer_stats_model.dart'; // NEW: Import CustomerStatsModel

class ApiService {
  final Dio _dio;
  final _storage = const FlutterSecureStorage();
  final String baseUrl = dotenv.env['API_BASE_URL'] ??
      'https://primejet-backend.onrender.com/api/v1'; //http://10.0.2.2:3000/api/v1';
  //https://primejet-backend.onrender.com/api/v1
  final String _nodeBackendUrl = kDebugMode
      ? 'https://primejet-backend.onrender.com/api/v1' // Or your local Node.js port
      : dotenv.env['NODE_BACKEND_URL'] ??
          'https://primejet-backend.onrender.com/api/v1';
  final String _firebaseFunctionsUrl = dotenv.env['FIREBASE_FUNCTIONS_URL'] ??
      'https://us-central1-primejetmobile-83583.cloudfunctions.net';
  final String _firebaseChatUrl = dotenv.env['FIREBASE_CHAT_URL'] ??
      'https://chatapi-ia3wcidvva-uc.a.run.app/api/v1/chat';

  final String _firebaseFcmUrl = dotenv.env['FIREBASE_FCM_URL'] ??
      'https://fcmapi-ia3wcidvva-uc.a.run.app/api/v1/fcm';

  Future<String?> _getToken() async {
    final token = await _storage.read(key: 'jwt_token');
    print(
        '[ApiService] Fetched token: ${token != null ? 'Present' : 'Absent'}');
    return token;
  }

  ApiService() : _dio = Dio() {
    // --- SETUP HAPPENS HERE ---
    _dio.options.baseUrl = 'https://primejet-backend.onrender.com/api/v1';

    // This "interceptor" automatically adds the auth token to every request
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options); // Continue with the request
        },
      ),
    );
  }

  Future<List<Message>> getChatHistory(String chatId, {int limit = 50}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final url = '$baseUrl/chat/$chatId/history?limit=$limit';
    debugPrint('[ApiService] getChatHistory -> $url');

    try {
      final resp = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      // Log everything so we can see the real server output if it fails
      debugPrint('[ApiService] getChatHistory status=${resp.statusCode}');
      debugPrint('[ApiService] getChatHistory body=${resp.body}');

      // ✅ Accept both shapes: `[{...}]` or `{ "messages": [{...}] }`
      if (resp.statusCode == 200) {
        final decoded = jsonDecode(resp.body);
        final List list = (decoded is List)
            ? decoded
            : (decoded['messages'] as List? ?? const []);
        return list
            .whereType<Map<String, dynamic>>()
            .map((e) => Message.fromJson(e))
            .toList();
      }

      // ✅ If the server replies 404 for “no history”, do NOT throw, just return []
      if (resp.statusCode == 404) {
        return <Message>[];
      }

      // Other errors: surface server message if present
      final decoded = (resp.body.isNotEmpty) ? jsonDecode(resp.body) : null;
      final serverMsg = (decoded is Map && decoded['error'] != null)
          ? decoded['error'].toString()
          : 'Failed to load chat history (HTTP ${resp.statusCode})';
      throw Exception(serverMsg);
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      debugPrint('[ApiService] getChatHistory error: $e');
      rethrow;
    }
  }

  Future<String> getFirebaseToken() async {
    try {
      final response = await _dio.post('/chat/firebase-token');
      return response.data['firebaseToken'] as String;
    } on DioException catch (e) {
      // ... your error handling
      throw Exception('Failed to get Firebase token');
    }
  }

  // Auth methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    final String apiUrl = '$baseUrl/auth/login';
    print('[ApiService] Attempting login to $apiUrl for email: $email');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] Login Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        final token = responseBody['token'] as String?;
        final userId = responseBody['userId'] as String?;
        final userName = responseBody['name'] as String?;
        final userRole = responseBody['role'] as String?;
        if (token != null &&
            userId != null &&
            userName != null &&
            userRole != null) {
          print(
              '[ApiService] Login successful for user: $userName ($userRole)');
          return {
            'token': token,
            'userId': userId,
            'name': userName,
            'role': userRole,
            'message': responseBody['message'] ?? 'Login successful.'
          };
        } else {
          print(
              '[ApiService] Login response missing essential data. Body: $responseBody');
          throw Exception('Login response missing essential data.');
        }
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Login failed: ${response.statusCode}';
        print('[ApiService] Login failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(
          '[ApiService] An unexpected error occurred during login: ${e.toString()}');
      throw Exception(
          'An unexpected error occurred during login: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    print('[ApiService] Logged out, token deleted.');
  }

  // User methods
  Future<app_user.User> getMyProfile() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getMyProfile: Not authenticated, token is null.');
      throw Exception('Not authenticated. Please log in.');
    }

    final String apiUrl = '$baseUrl/users/me';
    print('[ApiService] Getting my profile from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getMyProfile Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        return app_user.User.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to get profile';
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error fetching profile.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error fetching profile: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initiateChatSession({
    required String orderId,
    required String recipientId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final url = '$baseUrl/chat/initiate';
    final r = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'orderId': orderId, 'recipientId': recipientId}),
    );

    final body = jsonDecode(r.body);
    if (r.statusCode == 200) return (body as Map).cast<String, dynamic>();
    throw Exception(body['error'] ?? 'Cannot initiate chat session');
  }

  /*Future<Map<String, dynamic>> initiateChatSession({
    required String orderId,
    required String senderId,
    required String recipientId,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated to initiate chat.');
    }
    // This endpoint matches the one we created on the backend
    final String apiUrl = '$_firebaseChatUrl/initiate';

    print('ApiService: Initiating chat session via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderId': orderId,
          'senderId': senderId,
          'recipientId': recipientId,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        // 201 for Created
        print('ApiService: Chat session initiated successfully.');
        return responseBody; // Returns { chatId, message, participants }
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to initiate chat';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error initiating chat: ${e.toString()}');
      rethrow;
    }
  }*/

  Future<void> markOrderAsVerifying(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/orders/$orderId/mark-as-verifying';
    print('ApiService: Marking order $orderId as verifying payment.');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update order status to verifying.');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<AddressModel>> getMyAddresses() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getMyAddresses: Not authenticated, token is null.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses';
    print('[ApiService] Getting addresses from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getMyAddresses Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        final List<dynamic> addressesJson =
            responseBody as List<dynamic>? ?? [];
        return addressesJson
            .map((json) => AddressModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to get addresses: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching addresses: ${e.toString()}');
      throw Exception('Failed to fetch addresses: ${e.toString()}');
    }
  }

  Future<AddressModel> addAddress(AddressModel address) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] addAddress: Not authenticated, token is null.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses';
    print(
        '[ApiService] Creating address via $apiUrl with payload: ${address.toJson()}');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(address.toJson()),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] addAddress Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 201) {
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error creating address: ${e.toString()}');
      throw Exception('Failed to create address: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deleteAddress(String addressId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] deleteAddress: Not authenticated, token is null.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses/$addressId';
    print('[ApiService] Deleting address $addressId via $apiUrl');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] deleteAddress Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print(
            '[ApiService] Delete address successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to delete address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error deleting address $addressId: $e');
      throw Exception('Failed to delete address: ${e.toString()}');
    }
  }

  Future<SystemConfigModel> getSystemConfig() async {
    final token = await _getToken();

    final String apiUrl = '$baseUrl/config';
    print('[ApiService] Getting system configuration from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getSystemConfig Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        return SystemConfigModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to get system configuration');
      }
    } catch (e) {
      print('[ApiService] Error fetching system config: ${e.toString()}');
      rethrow;
    }
  }

  Future<String> getOrderPaymentStatus(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print(
          '[ApiService] getOrderPaymentStatus: Authentication token not found.');
      throw Exception('Authentication token not found.');
    }

    final String apiUrl = '$baseUrl/orders/$orderId/payment-status';
    print(
        '[ApiService] Fetching payment status for order $orderId via $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getOrderPaymentStatus Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        final paymentStatus = responseBody['paymentStatus'] as String;
        print(
            '[ApiService] getOrderPaymentStatus: Received status "$paymentStatus" for order $orderId.');
        return paymentStatus;
      } else {
        final errorMessage =
            responseBody['message'] ?? 'Failed to fetch payment status';
        print(
            '[ApiService] getOrderPaymentStatus failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching payment status: $e');
      rethrow;
    }
  }

  // Order methods
  Future<PlaceOrderResponseModel> placeOrder(
      Map<String, dynamic> orderPayload) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] placeOrder: Not authenticated to place order.');
      throw Exception('Not authenticated to place order.');
    }
    final String apiUrl = '$baseUrl/orders';
    print('[ApiService] Placing order to $apiUrl with payload: $orderPayload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(orderPayload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] placeOrder Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print(
            '[ApiService] Order placed successfully. Order ID: ${responseBody['order']['id']}');
        return PlaceOrderResponseModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Order placement failed';
        print('[ApiService] Order placement failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(
          '[ApiService] An unexpected error occurred while placing your order: ${e.toString()}');
      throw Exception('An unexpected error occurred while placing your order.');
    }
  }

  Future<app_order.Order> fetchOrderById(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] fetchOrderById: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('[ApiService] Fetching order $orderId from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] fetchOrderById Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Order $orderId fetched successfully.');
        return app_order.Order.fromJson(responseBody);
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to fetch order $orderId: ${response.statusCode}';
        print('[ApiService] fetchOrderById failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Failed to fetch order $orderId: ${e.toString()}');
      throw Exception('Failed to fetch order $orderId: ${e.toString()}');
    }
  }

  Future<List<app_order.Order>> getMyOrders() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getMyOrders: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/me';
    print('[ApiService] Fetching user orders from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getMyOrders Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Fetched user orders successfully.');
        return (responseBody['orders'] as List)
            .map((json) => app_order.Order.fromJson(json))
            .toList();
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to get orders';
        print('[ApiService] getMyOrders failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching user orders: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] cancelOrder: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('[ApiService] Attempting to cancel order $orderId via $apiUrl');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] cancelOrder Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Order cancel successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to cancel order: ${response.statusCode}';
        print(
            '[ApiService] Order cancel failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error cancelling order $orderId: $e');
      throw Exception('Failed to cancel order: ${e.toString()}');
    }
  }

  Future<app_order.Order> getOrderDetails(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getOrderDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('[ApiService] Getting order details from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getOrderDetails Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Order details fetched successfully.');
        return app_order.Order.fromJson(responseBody);
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to get order details: ${response.statusCode}';
        print('[ApiService] getOrderDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Failed to fetch order details: ${e.toString()}');
      throw Exception('Failed to fetch order details: ${e.toString()}');
    }
  }

  Future<CustomerStatsModel> getCustomerStats(String customerId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/me/stats'; // Correct, new endpoint

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // The backend now returns a complete object, so we use fromJson directly
        return CustomerStatsModel.fromJson(responseBody);
      } else {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to get customer stats');
      }
    } catch (e) {
      print('[ApiService] Error fetching customer stats: ${e.toString()}');
      throw Exception('Failed to process customer stats.');
    }
  }

  // FIX: Updated return type to CustomerStatsModel
  /*Future<CustomerStatsModel> getCustomerConsumptionData(
      String customerId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getCustomerConsumptionData: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl =
        '$baseUrl/orders/me/consumption-data'; // Assuming this endpoint returns aggregated stats
    print('[ApiService] Getting consumption data from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getCustomerConsumptionData Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Consumption data fetched successfully.');
        // FIX: Parse into CustomerStatsModel
        return CustomerStatsModel.fromJson(responseBody);
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to get consumption data';
        print(
            '[ApiService] getCustomerConsumptionData failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching consumption data: ${e.toString()}');
      rethrow;
    }
  }*/

  Future<Map<String, dynamic>> getWalletDetails() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getWalletDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/wallet';
    print('[ApiService] Getting wallet details from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getWalletDetails Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Wallet details fetched successfully.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load wallet details';
        print('[ApiService] getWalletDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching wallet details: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> updateChatThread({
    required String chatId,
    required String lastMessage,
    required String senderId,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateChatThread: Not authenticated.');
      return;
    }

    final String apiUrl = '$baseUrl/chat/update-thread';
    print(
        '[ApiService] Updating chat thread $chatId with last message: "$lastMessage" by sender: $senderId');
    final payload = {
      'chatId': chatId,
      'lastMessage': lastMessage,
      'senderId': senderId
    };
    print('[ApiService] updateChatThread Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] updateChatThread Response Status: ${response.statusCode}, Body: ${response.body}');
    } catch (e) {
      print('[ApiService] Could not update chat thread summary: $e');
    }
  }

  Future<Map<String, dynamic>> updateDriverAvailability(
      bool isAvailable) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateDriverAvailability: Not authenticated.');
      throw Exception('Not authenticated. Please log in.');
    }

    final String apiUrl = '$baseUrl/users/driver/availability';
    print(
        '[ApiService] Updating driver availability to $isAvailable via $apiUrl');
    final payload = {'isAvailableOnline': isAvailable};
    print('[ApiService] updateDriverAvailability Payload: $payload');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] updateDriverAvailability Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Driver availability updated successfully.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to update availability';
        print(
            '[ApiService] updateDriverAvailability failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error updating driver availability.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error updating driver availability: ${e.toString()}');
      rethrow;
    }
  }

  Future<DriverStatsModel> getDriverStats({String period = 'allTime'}) async {
    final token = await _getToken();
    if (token == null) {
      print(
          '[ApiService] getDriverStats: Not authenticated, returning empty model.');
      return DriverStatsModel.empty();
    }

    final uri = Uri.parse('$baseUrl/users/me/stats')
        .replace(queryParameters: {'period': period});
    print('[ApiService] Getting driver stats from $uri');
    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getDriverStats Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Driver stats fetched successfully.');
        return DriverStatsModel.fromJson(responseBody);
      } else {
        print(
            '[ApiService] Failed to load driver stats (${response.statusCode}), returning default. Error: ${responseBody['error'] ?? responseBody['message']}');
        return DriverStatsModel.empty();
      }
    } catch (e) {
      print('[ApiService] Error fetching driver stats: $e. Returning default.');
      return DriverStatsModel.empty();
    }
  }

  Future<DriverProfileModel> getMyDriverProfile() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getMyDriverProfile: Not authenticated.');
      throw Exception('Not authenticated. Please log in.');
    }

    final String apiUrl = '$baseUrl/users/me';
    print('[ApiService] Getting current driver profile from $apiUrl');
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getMyDriverProfile Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Driver profile fetched successfully.');
        return DriverProfileModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to get profile';
        print('[ApiService] getMyDriverProfile failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error fetching driver profile.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error fetching driver profile: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> driverUpdateStopStatus({
    required String runId,
    required String stopId,
    required String newStatus,
    String? notes,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] driverUpdateStopStatus: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl =
        '$baseUrl/runs/driver/runs/$runId/stops/$stopId/update-status';
    print(
        '[ApiService] Updating stop $stopId in run $runId to status $newStatus via $apiUrl');

    final body = <String, String>{'status': newStatus};
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }
    print('[ApiService] driverUpdateStopStatus Payload: $body');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] driverUpdateStopStatus Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Stop status updated successfully.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to update stop status';
        print(
            '[ApiService] driverUpdateStopStatus failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error updating stop status: ${e.toString()}');
      rethrow;
    }
  }

  Future<admin_run_models.AdminActiveRunDetailModel> adminCreateRunFromOrders(
      List<String> orderIds) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminCreateRunFromOrders: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/admin/create-batch';
    print('[ApiService] Creating run from orders: $orderIds via $apiUrl');
    final payload = {'orderIds': orderIds};
    print('[ApiService] adminCreateRunFromOrders Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminCreateRunFromOrders Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 201) {
        print('[ApiService] Run created successfully.');
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to create run';
        print(
            '[ApiService] adminCreateRunFromOrders failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error creating run from batch: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> endRun(String runId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] endRun: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/driver/runs/$runId/end';
    print('[ApiService] Ending run $runId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] endRun Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Run ended successfully.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to end run';
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error ending run.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error ending run: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createStripePaymentIntent(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print(
          '[ApiService] createStripePaymentIntent: Authentication token not found.');
      throw Exception('Authentication token not found.');
    }

    final String apiUrl = '$baseUrl/payments/stripe/intent';
    print(
        '[ApiService] Creating Stripe Payment Intent for order $orderId via $apiUrl');
    final payload = {'orderId': orderId};
    print('[ApiService] createStripePaymentIntent Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] createStripePaymentIntent Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Stripe Payment Intent created successfully.');
        if (responseBody['clientSecret'] == null) {
          print(
              '[ApiService] Client secret not found in PaymentIntent response. Body: $responseBody');
          throw Exception('Client secret not found in PaymentIntent response.');
        }
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create Stripe Payment Intent: ${response.statusCode}';
        print(
            '[ApiService] createStripePaymentIntent failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error creating Stripe Payment Intent: $e');
      throw Exception('Failed to create payment intent: ${e.toString()}');
    }
  }

  Future<PaymentMethodModel> attachPaymentMethod({
    required String stripePaymentMethodId,
    required String gateway,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] attachPaymentMethod: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/payments/attach-method';
    print(
        '[ApiService] Attaching payment method $stripePaymentMethodId for gateway $gateway via $apiUrl');
    final payload = {
      'paymentMethodId': stripePaymentMethodId,
      'gateway': gateway
    };
    print('[ApiService] attachPaymentMethod Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] attachPaymentMethod Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print('[ApiService] Payment method attached successfully.');
        return PaymentMethodModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to save payment method';
        print('[ApiService] attachPaymentMethod failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error attaching payment method: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? referralCode, // Accepts the optional referral code
  }) async {
    final String apiUrl = '$baseUrl/auth/register/customer';
    print(
        '[ApiService] Attempting customer registration to $apiUrl for email: $email');

    // Build the request body dynamically.
    final Map<String, String> body = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': password,
    };

    // Only add the referralCode to the body if it's not null and not empty.
    if (referralCode != null && referralCode.isNotEmpty) {
      body['referralCode'] = referralCode;
    }

    // Log the payload being sent (masking password for security).
    final logPayload = Map<String, String>.from(body);
    logPayload['password'] = '***';
    print('[ApiService] registerCustomer Payload: $logPayload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body), // Send the dynamically built body.
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] registerCustomer Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print('[ApiService] Customer registration successful.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Customer registration failed';
        print(
            '[ApiService] Customer registration failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error during customer registration: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final String apiUrl = '$baseUrl/auth/verify-otp';
    print('[ApiService] Verifying OTP for $email at $apiUrl');
    final payload = {'email': email, 'otp': otp};
    print('[ApiService] verifyOtp Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] verifyOtp Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] OTP verification successful.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ?? 'OTP verification failed';
        print('[ApiService] OTP verification failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error during OTP verification.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error during OTP verification: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> selfRegisterAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final String apiUrl = '$baseUrl/auth/register/admin';
    print(
        '[ApiService] Attempting admin self-registration to $apiUrl for $email');
    final payload = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': '***'
    };
    print('[ApiService] selfRegisterAdmin Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
        }),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] selfRegisterAdmin Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print('[ApiService] Admin self-registration successful.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Admin registration failed: ${response.statusCode}');
        print(
            '[ApiService] Admin self-registration failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('[ApiService] Network error during admin self-registration: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('[ApiService] HTTP error during admin self-registration: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('[ApiService] Unexpected error during admin self-registration: $e');
      throw Exception(
          'An unexpected error occurred during admin registration: ${e.toString()}');
    }
  }

  Future<app_user.User> adminCreateUser({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    final String apiUrl = '$baseUrl/users/admin';
    final token = await _getToken();

    if (token == null) {
      print('[ApiService] adminCreateUser: Admin not authenticated.');
      throw Exception('Admin not authenticated. Cannot create user.');
    }

    print('[ApiService] Admin creating user ($role) via $apiUrl for $email');
    final payload = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': '***',
      'role': role.toLowerCase()
    };
    print('[ApiService] adminCreateUser Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'role': role.toLowerCase(),
        }),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminCreateUser Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print('[ApiService] User creation by admin successful.');
        return app_user.User.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            'Admin user creation failed: ${response.statusCode}';
        print(
            '[ApiService] Admin user creation failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('[ApiService] Network error during admin user creation: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('[ApiService] HTTP error during admin user creation: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('[ApiService] Unexpected error during admin user creation: $e');
      throw Exception(
          'An unexpected error occurred during user creation: ${e.toString()}');
    }
  }

  Future<DashboardStatsModel> getAdminDashboardStats() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getAdminDashboardStats: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/admin/dashboard-stats';
    print('[ApiService] Getting admin dashboard stats from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getAdminDashboardStats Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin dashboard stats fetched successfully.');
        return DashboardStatsModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load dashboard stats';
        print(
            '[ApiService] getAdminDashboardStats failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error fetching admin dashboard stats.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error fetching admin stats: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> adminGetCustomers({
    int page = 1,
    int limit = 15,
    String? searchQuery,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetCustomers: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final queryParams = <String, String>{
      'role': 'customer',
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }

    final uri =
        Uri.parse('$baseUrl/users/admin').replace(queryParameters: queryParams);
    print(
        '[ApiService] Getting admin customers from $uri with query: $queryParams');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetCustomers Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin customers fetched successfully.');
        final List<AdminCustomerSummaryModel> customers =
            (responseBody['users'] as List)
                .map((data) => AdminCustomerSummaryModel.fromJson(
                    data as Map<String, dynamic>))
                .toList();

        return {
          'customers': customers,
          'currentPage': responseBody['currentPage'],
          'totalPages': responseBody['totalPages'],
        };
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load customers';
        print('[ApiService] adminGetCustomers failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin customers: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminAssignDriver(String orderId, String driverId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminAssignDriver: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/orders/admin/$orderId/assign-driver';
    print(
        '[ApiService] Admin assigning driver $driverId to order $orderId via $apiUrl');
    final payload = {'driverId': driverId};
    print('[ApiService] adminAssignDriver Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminAssignDriver Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to assign driver';
        print('[ApiService] adminAssignDriver failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Driver assigned to order successfully.');
      }
    } catch (e) {
      print('[ApiService] Error assigning driver to order: ${e.toString()}');
      rethrow;
    }
  }

  Future<AdminDriverDetailModel> adminGetDriverDetails(String driverId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetDriverDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/users/admin/$driverId';
    print('[ApiService] Getting driver details for $driverId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetDriverDetails Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Driver details fetched successfully.');
        return AdminDriverDetailModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load driver details';
        print(
            '[ApiService] adminGetDriverDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching driver details: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminUpdateUserStatus(String userId, String status) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminUpdateUserStatus: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/users/admin/$userId/status';
    print('[ApiService] Updating user $userId status to $status via $apiUrl');
    final payload = {'status': status};
    print('[ApiService] adminUpdateUserStatus Payload: $payload');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminUpdateUserStatus Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to update user status';
        print(
            '[ApiService] adminUpdateUserStatus failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] User status updated successfully.');
      }
    } catch (e) {
      print('[ApiService] Error updating user status: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminSetDriverAvailability(
      String driverId, bool isAvailable) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminSetDriverAvailability: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/users/admin/$driverId';
    print(
        '[ApiService] Admin setting availability for driver $driverId to $isAvailable via $apiUrl');
    final payload = {'isAvailableOnline': isAvailable};
    print('[ApiService] adminSetDriverAvailability Payload: $payload');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminSetDriverAvailability Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to update availability';
        print(
            '[ApiService] adminSetDriverAvailability failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print(
            '[ApiService] Driver availability updated successfully by admin.');
      }
    } catch (e) {
      print('[ApiService] Error setting driver availability: ${e.toString()}');
      rethrow;
    }
  }

  Future<admin_run_models.AdminActiveRunDetailModel> adminGetRunDetails(
      String runId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetRunDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/$runId';
    print('[ApiService] Getting admin run details for $runId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetRunDetails Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin run details fetched successfully.');
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load run details';
        print('[ApiService] adminGetRunDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin run details: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<admin_run_models.AdminPickupBatchSummary>>
      adminGetPendingBatches() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetPendingBatches: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/runs/admin/pending-batches';
    print('[ApiService] Getting admin pending batches from $apiUrl');
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetPendingBatches Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Admin pending batches fetched successfully.');
        return (responseBody as List)
            .map((data) =>
                admin_run_models.AdminPickupBatchSummary.fromJson(data))
            .toList();
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load pending batches';
        print(
            '[ApiService] adminGetPendingBatches failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(
          '[ApiService] Error fetching admin pending batches: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<admin_run_models.AdminActiveRunInfo>> adminGetActiveRuns() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetActiveRuns: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/runs/admin/active';
    print('[ApiService] Getting admin active runs from $apiUrl');
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetActiveRuns Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Admin active runs fetched successfully.');
        return (responseBody as List)
            .map((data) => admin_run_models.AdminActiveRunInfo.fromJson(data))
            .toList();
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load active runs';
        print('[ApiService] adminGetActiveRuns failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin active runs: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<admin_run_models.AdminUnassignedOrder>>
      adminGetUnassignedOrders() async {
    print('[ApiService] Attempting to fetch unassigned orders...');
    try {
      final Map<String, dynamic> response =
          await adminGetOrders(status: "Order Confirmed");
      final List<AdminOrderSummaryModel> orders =
          response['orders'] as List<AdminOrderSummaryModel>? ?? [];
      print(
          '[ApiService] Successfully fetched ${orders.length} unassigned orders.');
      return orders
          .map((order) =>
              admin_run_models.AdminUnassignedOrder.fromOrderSummary(order))
          .toList();
    } catch (e) {
      print('[ApiService] Could not fetch unassigned orders. Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> adminGetOrders({
    int page = 1,
    int limit = 15,
    String? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetOrders (filtered): Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      'sortBy': '-orderDate',
    };

    if (status != null && status != "All") queryParams['status'] = status;
    if (searchQuery != null && searchQuery.isNotEmpty)
      queryParams['search'] = searchQuery;
    if (startDate != null)
      queryParams['dateRangeStart'] = startDate.toIso8601String();
    if (endDate != null)
      queryParams['dateRangeEnd'] = endDate.toIso8601String();

    final uri = Uri.parse('$baseUrl/orders/admin')
        .replace(queryParameters: queryParams);
    print(
        '[ApiService] Getting admin orders from $uri with query: $queryParams');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetOrders (filtered) Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin orders fetched successfully.');
        final List<AdminOrderSummaryModel> orders = (responseBody['orders']
                as List)
            .map((data) =>
                AdminOrderSummaryModel.fromJson(data as Map<String, dynamic>))
            .toList();

        return {
          'orders': orders,
          'currentPage': responseBody['currentPage'],
          'totalPages': responseBody['totalPages'],
        };
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to load orders';
        print(
            '[ApiService] adminGetOrders (filtered) failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(
          '[ApiService] Error fetching admin orders (filtered): ${e.toString()}');
      rethrow;
    }
  }

  Future<List<admin_run_models.AvailableDriverForMap>>
      adminGetAvailableDrivers() async {
    print('[ApiService] Attempting to fetch available drivers...');
    try {
      final Map<String, dynamic> response =
          await adminGetDrivers(isAvailableOnline: true, limit: 100);
      final List<AdminDriverSummaryModel> drivers =
          response['drivers'] as List<AdminDriverSummaryModel>? ?? [];
      print(
          '[ApiService] Successfully fetched ${drivers.length} available drivers.');
      return drivers
          .map((driver) =>
              admin_run_models.AvailableDriverForMap.fromDriverSummary(driver))
          .toList();
    } catch (e) {
      print('[ApiService] Could not fetch available drivers. Error: $e');
      return [];
    }
  }

  Future<void> adminAssignDriverToRun(String runId, String driverId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminAssignDriverToRun: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/runs/admin/$runId/assign-driver';
    print(
        '[ApiService] Admin assigning driver $driverId to run $runId via $apiUrl');
    final payload = {'driverId': driverId};
    print('[ApiService] adminAssignDriverToRun Payload: $payload');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminAssignDriverToRun Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to assign driver to run';
        print(
            '[ApiService] adminAssignDriverToRun failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Driver assigned to run successfully.');
      }
    } catch (e) {
      print('[ApiService] Error assigning driver to run: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final String apiUrl = '$baseUrl/auth/request-password-reset';
    print('[ApiService] Requesting password reset for $email to $apiUrl');
    final payload = {'email': email};
    print('[ApiService] requestPasswordReset Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] requestPasswordReset Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Password reset request successful.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Password reset request failed: ${response.statusCode}');
        print(
            '[ApiService] Password reset request failed. Status: ${response.statusCode}, Error: $errorMessage, Body: $responseBody');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('[ApiService] Network error during password reset request: $e');
      throw Exception(
          'Network error: Please check your connection and ensure local server is running.');
    } on HttpException catch (e) {
      print('[ApiService] HTTP error during password reset request: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('[ApiService] Unexpected error during password reset request: $e');
      throw Exception(
          'An unexpected error occurred while requesting password reset: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> verifyPasswordResetToken({
    required String email,
    required String token,
  }) async {
    final String apiUrl = '$baseUrl/auth/verify-password-token';
    final payload = {'email': email, 'token': token};
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(responseBody['error'] ?? 'Token verification failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getReferralInfo() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getReferralInfo: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/referrals';
    print('[ApiService] Getting referral info from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getReferralInfo Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Referral info fetched successfully.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load referral info';
        print('[ApiService] getReferralInfo failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching referral info: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final String apiUrl = '$baseUrl/auth/reset-password';
    print('[ApiService] Attempting to reset password with token to $apiUrl');
    final payload = {'token': token, 'newPassword': '***'};
    print('[ApiService] resetPassword Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'token': token,
          'newPassword': newPassword,
        }),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] resetPassword Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Password reset successful.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Password reset failed: ${response.statusCode}');
        print(
            '[ApiService] Password reset failed. Status: ${response.statusCode}, Error: $errorMessage, Body: $responseBody');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('[ApiService] Network error during password reset: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('[ApiService] HTTP error during password reset: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('[ApiService] Unexpected error during password reset: $e');
      throw Exception(
          'An unexpected error occurred while resetting password: ${e.toString()}');
    }
  }

  Future<List<DealModel>> getActivePromotions() async {
    final String apiUrl = '$baseUrl/promotions/active';
    print('[ApiService] Getting active promotions from $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl));
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getActivePromotions Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Active promotions fetched successfully.');
        final List<dynamic> promotionsJson =
            responseBody as List<dynamic>? ?? [];
        return promotionsJson
            .map((json) =>
                DealModel.fromBackendPromotion(json as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to get active promotions: ${response.statusCode}';
        print('[ApiService] getActivePromotions failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching active promotions: $e');
      throw Exception('Failed to fetch promotions: ${e.toString()}');
    }
  }

  Future<List<AdminPromotionModel>> adminGetPromotions() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetPromotions: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/promotions';
    print('[ApiService] Getting all promotions for admin from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetPromotions Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin promotions fetched successfully.');
        final List<dynamic> promotionsJson =
            responseBody['promotions'] as List<dynamic>? ?? [];
        return promotionsJson
            .map((data) => AdminPromotionModel.fromJson(data))
            .toList();
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load promotions';
        print('[ApiService] adminGetPromotions failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin promotions: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminCreatePromotion(Map<String, dynamic> promotionData) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminCreatePromotion: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/promotions';
    print(
        '[ApiService] Creating promotion via $apiUrl with payload: $promotionData');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(promotionData),
      );
      print(
          '[ApiService] adminCreatePromotion Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to create promotion';
        print('[ApiService] adminCreatePromotion failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Promotion created successfully.');
      }
    } catch (e) {
      print('[ApiService] Error creating promotion: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminUpdatePromotion(
      String promoId, Map<String, dynamic> updateData) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminUpdatePromotion: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/promotions/$promoId';
    print(
        '[ApiService] Updating promotion $promoId via $apiUrl with payload: $updateData');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(updateData),
      );
      print(
          '[ApiService] adminUpdatePromotion Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to update promotion';
        print('[ApiService] adminUpdatePromotion failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Promotion updated successfully.');
      }
    } catch (e) {
      print('[ApiService] Error updating promotion: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminDeletePromotion(String promoId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminDeletePromotion: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/promotions/$promoId';
    print('[ApiService] Deleting promotion $promoId via $apiUrl');

    try {
      final response = await http.delete(Uri.parse(apiUrl),
          headers: {'Authorization': 'Bearer $token'});
      print(
          '[ApiService] adminDeletePromotion Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to delete promotion';
        print('[ApiService] adminDeletePromotion failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Promotion deleted successfully.');
      }
    } catch (e) {
      print('[ApiService] Error deleting promotion: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getCustomerOrders({
    String? status,
    int page = 1,
    int limit = 10,
    String? sortBy = '-orderDate',
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getCustomerOrders: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParameters['sortBy'] = sortBy;
    }

    final uri =
        Uri.parse('$baseUrl/orders').replace(queryParameters: queryParameters);
    print(
        '[ApiService] Getting customer orders from $uri with query: $queryParameters');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getCustomerOrders Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Customer orders fetched successfully.');
        final List<dynamic> ordersJson =
            responseBody['orders'] as List<dynamic>? ?? [];
        final List<app_order.Order> typedOrders = ordersJson
            .map((json) =>
                app_order.Order.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'orders': typedOrders,
          'currentPage': responseBody['currentPage'] as int? ?? 1,
          'totalPages': responseBody['totalPages'] as int? ?? 1,
          'totalOrders': responseBody['totalOrders'] as int? ?? 0,
        };
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch orders: ${response.statusCode}';
        print('[ApiService] getCustomerOrders failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching orders: ${e.toString()}');
      throw Exception('Failed to list orders due to an unexpected error.');
    }
  }

  Future<Map<String, dynamic>> registerDriver({
    required String name,
    required String email,
    required String phone,
    required String password,
    required Map<String, String> bankDetails,
  }) async {
    final String apiUrl = '$baseUrl/auth/register/driver';
    print('[ApiService] Attempting driver registration to $apiUrl for $email');
    final payload = {
      'name': name,
      'email': email,
      'phone': phone,
      'password': '***',
      'bankDetails': bankDetails
    };
    print('[ApiService] registerDriver Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'email': email,
          'phone': phone,
          'password': password,
          'bankDetails': bankDetails,
        }),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] registerDriver Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 201) {
        print('[ApiService] Driver registration successful.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Driver registration failed: ${response.statusCode}');
        print(
            '[ApiService] Driver registration failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('[ApiService] Network error during driver registration: $e');
      throw Exception(
          'Network error: Please check your connection and ensure local server is running.');
    } on HttpException catch (e) {
      print('[ApiService] HTTP error during driver registration: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('[ApiService] Unexpected error during driver registration: $e');
      throw Exception(
          'An unexpected error occurred during driver registration: ${e.toString()}');
    }
  }

  Future<List<admin_run_models.AdminActiveRunInfo>> getAssignedRuns() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getAssignedRuns: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/driver/assigned-runs';
    print('[ApiService] Fetching assigned runs for driver from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getAssignedRuns Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Assigned runs for driver fetched successfully.');
        final List<dynamic> runsJson = responseBody as List<dynamic>? ?? [];
        return runsJson
            .map((json) => admin_run_models.AdminActiveRunInfo.fromJson(
                json as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch assigned runs';
        print('[ApiService] getAssignedRuns failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching assigned runs: ${e.toString()}');
      rethrow;
    }
  }

  Future<admin_run_models.AdminActiveRunDetailModel> getRunDetails(
      String runId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getRunDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/$runId';
    print('[ApiService] Fetching details for run $runId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getRunDetails Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Run details fetched successfully.');
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody as Map<String, dynamic>);
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch run details';
        print('[ApiService] getRunDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching run details: ${e.toString()}');
      throw Exception('Error fetching run details: ${e.toString()}');
    }
  }

  Future<AdminOrderDetailModel> adminGetOrderDetails(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetOrderDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/orders/$orderId';
    print('[ApiService] Getting admin order details for $orderId from $apiUrl');
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetOrderDetails Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin order details fetched successfully.');
        return AdminOrderDetailModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load order details';
        print('[ApiService] adminGetOrderDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin order details: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminUpdateOrderStatus(String orderId, String newStatus,
      {String? notes}) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminUpdateOrderStatus: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/admin/$orderId/status';
    print(
        '[ApiService] Updating order $orderId status to $newStatus via $apiUrl');

    final payload = <String, String>{'status': newStatus};
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }
    print('[ApiService] adminUpdateOrderStatus Payload: $payload');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminUpdateOrderStatus Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to update order status';
        print(
            '[ApiService] adminUpdateOrderStatus failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Order status updated successfully by admin.');
      }
    } catch (e) {
      print('[ApiService] Error updating order status: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminAddNoteToOrder(String orderId, String noteText) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminAddNoteToOrder: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/orders/admin/$orderId/notes';
    print(
        '[ApiService] Adding note to order $orderId via $apiUrl with note: "$noteText"');
    final payload = {'note': noteText};
    print('[ApiService] adminAddNoteToOrder Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminAddNoteToOrder Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMessage = body['error'] ?? 'Failed to add note';
        print('[ApiService] adminAddNoteToOrder failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Note added to order successfully by admin.');
      }
    } catch (e) {
      print('[ApiService] Error adding note to order: ${e.toString()}');
      rethrow;
    }
  }

  // 2) Customer threads
  Future<List<ChatThreadModel>> getChatThreads() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final url = '$baseUrl/chat/my-threads';
    debugPrint('ApiService: getChatThreads -> $url');

    try {
      final r = await http.get(
        Uri.parse(url),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = jsonDecode(r.body);

      if (r.statusCode == 200) {
        final list = (body as List?) ?? [];
        return list
            .whereType<Map<String, dynamic>>()
            .map((j) => ChatThreadModel.fromJson(j))
            .toList();
      }
      throw Exception(body['error'] ?? 'Failed to load threads');
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      debugPrint('ApiService: Error fetching chat threads: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> acceptRun(String runId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] acceptRun: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/runs/driver/runs/$runId/accept';
    print('[ApiService] Accepting run $runId via $apiUrl');

    try {
      final response = await http.post(Uri.parse(apiUrl), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      });
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] acceptRun Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Run accepted successfully.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to accept run';
        print('[ApiService] acceptRun failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error accepting run: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> setDefaultAddress(String addressId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses/$addressId/default';
    print('[ApiService] Setting default address $addressId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] setDefaultAddress Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Set default address successful.');
        // It returns a map with a 'message', so we return that directly.
        return responseBody as Map<String, dynamic>;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to set default address';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error setting default address $addressId: $e');
      throw Exception('Failed to set default address: ${e.toString()}');
    }
  }

  Future<AddressModel> createAddress(Map<String, dynamic> addressData) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] createAddress: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses';
    print(
        '[ApiService] Creating address via $apiUrl with payload: $addressData');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(addressData),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] createAddress Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 201) {
        print('[ApiService] Address created successfully.');
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Failed to create address: ${e.toString()}');
      throw Exception('Failed to create address: ${e.toString()}');
    }
  }

  Future<AddressModel> updateAddress(
      String addressId, Map<String, dynamic> addressData) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateAddress: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses/$addressId';
    print(
        '[ApiService] Updating address $addressId via $apiUrl with payload: $addressData');
    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token'
        },
        body: jsonEncode(addressData),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] updateAddress Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Address updated successfully.');
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to update address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Failed to update address: ${e.toString()}');
      throw Exception('Failed to update address: ${e.toString()}');
    }
  }

  Future<void> updateSystemConfig(admin_model.SystemConfigModel config) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateSystemConfig: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/config';
    print(
        '[ApiService] Updating system configuration at $apiUrl with payload: ${config.toJson()}');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(config.toJson()),
      );
      print(
          '[ApiService] updateSystemConfig Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to update configuration';
        print('[ApiService] updateSystemConfig failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] System configuration updated successfully.');
      }
    } catch (e) {
      print('[ApiService] Error updating system config: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<app_user.User>> getUsers() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getUsers: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/users/admin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] getUsers Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 200) {
      print('[ApiService] Users fetched successfully.');
      final Map<String, dynamic> data = responseBody;
      final List<dynamic> usersList = data['users'];
      return usersList.map((json) => app_user.User.fromJson(json)).toList();
    } else {
      final errorMessage = responseBody['error'] ?? 'Failed to fetch users';
      print('[ApiService] getUsers failed. Error: $errorMessage');
      throw Exception('Failed to fetch users: ${response.body}');
    }
  }

  Future<void> deleteUser(String userId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] deleteUser: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final response = await http.delete(
      Uri.parse('$baseUrl/users/admin/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    print(
        '[ApiService] deleteUser Response Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to delete user';
      print('[ApiService] deleteUser failed. Error: $errorMessage');
      throw Exception('$errorMessage: ${response.statusCode}');
    } else {
      print('[ApiService] User deleted successfully.');
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateUserRole: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final payload = {'role': role};
    print(
        '[ApiService] Updating role for user $userId to $role via $baseUrl/users/admin/$userId');
    print('[ApiService] updateUserRole Payload: $payload');
    final response = await http.put(
      Uri.parse('$baseUrl/users/admin/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(payload),
    );
    print(
        '[ApiService] updateUserRole Response Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to update role';
      print('[ApiService] updateUserRole failed. Error: $errorMessage');
      throw Exception('$errorMessage: ${response.statusCode}');
    } else {
      print('[ApiService] User role updated successfully.');
    }
  }

  Future<app_user.User> updateProfile(Map<String, dynamic> updateData) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] updateProfile: Not authenticated.');
      throw Exception('Not authenticated. Please log in.');
    }

    final String apiUrl = '$baseUrl/users/me';
    print(
        '[ApiService] Updating my profile at $apiUrl with payload: $updateData');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] updateProfile Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Profile updated successfully.');
        return app_user.User.fromJson(responseBody['user']);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to update profile';
        print('[ApiService] updateProfile failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error updating profile.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error updating profile: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> processPayment(
      String orderId, double amount, String transactionId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] processPayment: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final payload = {
      'orderId': orderId,
      'amount': (amount * 100).toInt(),
      'transactionId': transactionId
    };
    print(
        '[ApiService] Processing payment for order $orderId via $baseUrl/orders/$orderId/payment');
    print('[ApiService] processPayment Payload: $payload');
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/payment'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(payload),
    );
    print(
        '[ApiService] processPayment Response Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage =
          responseBody['error'] ?? responseBody['message'] ?? 'Payment failed';
      print('[ApiService] processPayment failed. Error: $errorMessage');
      throw Exception('$errorMessage: ${response.statusCode}');
    } else {
      print(
          '[ApiService] Payment processed successfully on backend (legacy method).');
    }
  }

  Future<List<NotificationModel>> getNotifications() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getNotifications: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/notifications';
    print('[ApiService] Fetching notifications from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getNotifications Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        if (responseBody is Map<String, dynamic> &&
            responseBody.containsKey('notifications')) {
          print('[ApiService] Notifications fetched successfully.');
          final List<dynamic> notificationsJson =
              responseBody['notifications'] as List<dynamic>? ?? [];
          return notificationsJson
              .map((json) =>
                  NotificationModel.fromJson(json as Map<String, dynamic>))
              .toList();
        } else {
          throw Exception('Unexpected API response format for notifications.');
        }
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to load notifications';
        print('[ApiService] getNotifications failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching notifications: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] markNotificationAsRead: Not authenticated.');
      return;
    }
    final String apiUrl = '$baseUrl/notifications/$notificationId/read';
    print(
        '[ApiService] Marking notification $notificationId as read via $apiUrl');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          '[ApiService] markNotificationAsRead Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        print(
            '[ApiService] Failed to mark notification $notificationId as read. Status: ${response.statusCode}, Body: ${response.body}');
      } else {
        print('[ApiService] Notification marked as read successfully.');
      }
    } catch (e) {
      print(
          '[ApiService] Could not mark notification $notificationId as read: $e');
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] markAllNotificationsAsRead: Not authenticated.');
      return;
    }
    final String apiUrl = '$baseUrl/notifications/mark-all-read';
    print('[ApiService] Marking all notifications as read via $apiUrl');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          '[ApiService] markAllNotificationsAsRead Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        print(
            '[ApiService] Failed to mark all notifications as read. Status: ${response.statusCode}, Body: ${response.body}');
      } else {
        print('[ApiService] All notifications marked as read successfully.');
      }
    } catch (e) {
      print('[ApiService] Could not mark all notifications as read: $e');
    }
  }

  Future<void> clearAllNotifications() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] clearAllNotifications: Not authenticated.');
      return;
    }
    final String apiUrl = '$baseUrl/notifications/all';
    print('[ApiService] Clearing all notifications via $apiUrl');
    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          '[ApiService] clearAllNotifications Response Status: ${response.statusCode}, Body: ${response.body}');
      if (response.statusCode != 200) {
        print(
            '[ApiService] Failed to clear all notifications. Status: ${response.statusCode}, Body: ${response.body}');
      } else {
        print('[ApiService] All notifications cleared successfully.');
      }
    } catch (e) {
      print('[ApiService] Could not clear all notifications: $e');
    }
  }

  Future<List<app_location.Location>> getLocationHistory(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getLocationHistory: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/location-history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] getLocationHistory Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 200) {
      print('[ApiService] Location history fetched successfully.');
      final List<dynamic> data = responseBody;
      return data.map((json) => app_location.Location.fromJson(json)).toList();
    } else {
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to fetch location history';
      print('[ApiService] getLocationHistory failed. Error: $errorMessage');
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> adminGetDrivers({
    int page = 1,
    int limit = 15,
    String? searchQuery,
    String? accountStatus,
    bool? isAvailableOnline,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetDrivers: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final queryParams = <String, String>{
      'role': 'driver',
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }
    if (accountStatus != null && accountStatus != "All") {
      queryParams['status'] = accountStatus;
    }
    if (isAvailableOnline != null) {
      queryParams['isAvailableOnline'] = isAvailableOnline.toString();
    }

    final uri =
        Uri.parse('$baseUrl/users/admin').replace(queryParameters: queryParams);
    print(
        '[ApiService] Getting admin drivers from $uri with query: $queryParams');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetDrivers Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin drivers fetched successfully.');
        final List<AdminDriverSummaryModel> drivers = (responseBody['users']
                as List)
            .map((data) =>
                AdminDriverSummaryModel.fromJson(data as Map<String, dynamic>))
            .toList();

        return {
          'drivers': drivers,
          'currentPage': responseBody['currentPage'],
          'totalPages': responseBody['totalPages'],
        };
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to load drivers';
        print('[ApiService] adminGetDrivers failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin drivers: ${e.toString()}');
      rethrow;
    }
  }

  Future<AdminCustomerDetailModel> adminGetCustomerDetails(
      String customerId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetCustomerDetails: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/users/admin/$customerId';
    print('[ApiService] Getting customer details for $customerId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetCustomerDetails Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Customer details fetched successfully by admin.');
        return AdminCustomerDetailModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load customer details';
        print(
            '[ApiService] adminGetCustomerDetails failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print(
          '[ApiService] Error fetching admin customer details: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> adminTriggerPasswordReset(String email) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminTriggerPasswordReset: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/auth/request-password-reset';
    print(
        '[ApiService] Admin triggering password reset for $email via $apiUrl');
    final payload = {'email': email};
    print('[ApiService] adminTriggerPasswordReset Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      print(
          '[ApiService] adminTriggerPasswordReset Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to trigger password reset';
        print(
            '[ApiService] adminTriggerPasswordReset failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Password reset triggered successfully by admin.');
      }
    } catch (e) {
      print('[ApiService] Error triggering password reset: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitFeedback(
      String orderId, app_feedback.Feedback feedback) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] submitFeedback: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final payload = feedback.toJson();
    print(
        '[ApiService] Submitting feedback for order $orderId via $baseUrl/orders/$orderId/feedback with payload: $payload');
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/feedback'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(payload),
    );
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] submitFeedback Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 201) {
      print('[ApiService] Feedback submitted successfully.');
      return responseBody;
    } else {
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to submit feedback';
      print('[ApiService] submitFeedback failed. Error: $errorMessage');
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final String apiUrl = '$baseUrl/auth/google/mobile-signin';
    print('[ApiService] Attempting Google Sign-In with ID Token via $apiUrl');
    // Don't log full ID token
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] googleSignIn Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print('[ApiService] Google Sign-In successful.');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Google Sign-In failed on the server.';
        print('[ApiService] Google Sign-In failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error during Google Sign-In: ${e.toString()}');
      rethrow;
    }
  }

  Future<ReferralModel> getReferralInformation(String customerId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getReferralInformation: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/referrals';
    print(
        '[ApiService] Getting referral info for customer $customerId from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getReferralInformation Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Referral information fetched successfully.');
        return ReferralModel.fromJson(responseBody);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to get referral information';
        print(
            '[ApiService] getReferralInformation failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error fetching referral information.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print(
          '[ApiService] Error fetching referral information: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> adminGetReferrals({
    int page = 1,
    int limit = 10,
    String? searchQuery,
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetReferrals: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }

    final uri = Uri.parse('$baseUrl/referrals/admin')
        .replace(queryParameters: queryParams);
    print(
        '[ApiService] Getting admin referrals from $uri with query: $queryParams');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetReferrals Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Admin referrals fetched successfully.');
        final List<AdminReferralSummaryModel> referrals =
            (responseBody['referrals'] as List)
                .map((data) => AdminReferralSummaryModel.fromJson(
                    data as Map<String, dynamic>))
                .toList();

        return {
          'referrals': referrals,
          'currentPage': responseBody['currentPage'],
          'totalPages': responseBody['totalPages'],
          'totalReferrals': responseBody['totalReferrals'],
        };
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to load referrals';
        print('[ApiService] adminGetReferrals failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching admin referrals: ${e.toString()}');
      rethrow;
    }
  }

  // Add this function. If it already exists, replace it.
  Future<void> registerFcmToken(String token) async {
    final authToken = await _getToken();
    if (authToken == null) {
      print('[ApiService] registerFcmToken: User not authenticated. Skipping.');
      return;
    }

    // CORRECTED: URL and HTTP Method
    //final String apiUrl = '$baseUrl/users/fcm-token';
    final String apiUrl = '$_nodeBackendUrl/users/me/fcm-token';

    try {
      final response = await http.put(
        // Use PUT
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode == 200) {
        print('[ApiService] FCM token registered successfully.');
      } else {
        print(
            '[ApiService] Failed to register FCM token. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('[ApiService] Error registering FCM token: $e');
    }
  }

  Future<String> getAgoraToken(String channelName) async {
    final token = await _getToken();
    if (token == null) {
      print(
          '[ApiService] getAgoraToken: Not authenticated. Cannot get Agora token.');
      throw Exception('Not authenticated. Cannot get Agora token.');
    }

    final String apiUrl = '$baseUrl/voice/agora-token';
    print(
        '[ApiService] Requesting Agora token for channel "$channelName" from $apiUrl');
    final payload = {'channelName': channelName};
    print('[ApiService] getAgoraToken Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getAgoraToken Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        final String agoraToken = responseBody['token'] as String;
        print('[ApiService] Successfully received Agora token.');
        return agoraToken;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to get Agora token';
        print('[ApiService] getAgoraToken failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException {
      print('[ApiService] Network error getting Agora token.');
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('[ApiService] Error getting Agora token: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> adminGetReport({
    required String reportType,
    String period = 'weekly',
  }) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetReport: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final uri = Uri.parse('$baseUrl/reports').replace(queryParameters: {
      'reportType': reportType,
      'period': period,
    });

    print('[ApiService] Getting report from $uri');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] adminGetReport Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Report fetched successfully.');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to load report';
        print('[ApiService] adminGetReport failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error getting report: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initializeCardTokenization() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] initializeCardTokenization: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/payments/tokenize-card/initialize';
    print('[ApiService] Initializing card tokenization via $apiUrl');
    final response = await http
        .post(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] initializeCardTokenization Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 200) {
      print('[ApiService] Card tokenization initialized successfully.');
      return responseBody;
    } else {
      final errorMessage =
          responseBody['error'] ?? 'Failed to initialize card tokenization.';
      print(
          '[ApiService] initializeCardTokenization failed. Error: $errorMessage');
      throw Exception('Failed to initialize card tokenization.');
    }
  }

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] getPaymentMethods: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/payments/methods';
    print('[ApiService] Getting payment methods from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] getPaymentMethods Response Status: ${response.statusCode}, Body: $responseBody');

      if (response.statusCode == 200) {
        print('[ApiService] Payment methods fetched successfully.');
        final List<dynamic> methodsJson = responseBody as List<dynamic>? ?? [];
        return methodsJson
            .map((json) =>
                PaymentMethodModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to load payment methods';
        print('[ApiService] getPaymentMethods failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Error fetching payment methods: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createSetupIntent() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] createSetupIntent: Not authenticated.');
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/payments/setup-intent';
    print('[ApiService] Creating SetupIntent via $apiUrl');
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] createSetupIntent Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 200) {
      print('[ApiService] SetupIntent created successfully.');
      return responseBody;
    } else {
      final errorMessage =
          responseBody['error'] ?? 'Failed to initialize card setup';
      print('[ApiService] createSetupIntent failed. Error: $errorMessage');
      throw Exception('Failed to initialize card setup');
    }
  }

  Future<Map<String, dynamic>> adminGetPaymentConfig() async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminGetPaymentConfig: Admin not authenticated.');
      throw Exception('Admin not authenticated.');
    }
    final String apiUrl = '$baseUrl/admin/config/payment-gateway';
    print('[ApiService] Getting admin payment config from $apiUrl');
    final response = await http
        .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
    final responseBody = jsonDecode(response.body);
    print(
        '[ApiService] adminGetPaymentConfig Response Status: ${response.statusCode}, Body: $responseBody');
    if (response.statusCode == 200) {
      print('[ApiService] Admin payment config fetched successfully.');
      return responseBody;
    } else {
      final errorMessage =
          responseBody['error'] ?? 'Failed to fetch payment configuration.';
      print('[ApiService] adminGetPaymentConfig failed. Error: $errorMessage');
      throw Exception('Failed to fetch payment configuration.');
    }
  }

  Future<void> adminUpdatePaymentGateway(String gateway) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] adminUpdatePaymentGateway: Admin not authenticated.');
      throw Exception('Admin not authenticated.');
    }
    final String apiUrl = '$baseUrl/admin/config/payment-gateway';
    print('[ApiService] Updating payment gateway to $gateway via $apiUrl');
    final payload = {'gateway': gateway};
    print('[ApiService] adminUpdatePaymentGateway Payload: $payload');
    final response = await http.patch(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(payload),
    );
    print(
        '[ApiService] adminUpdatePaymentGateway Response Status: ${response.statusCode}, Body: ${response.body}');
    if (response.statusCode != 200) {
      final errorMessage = jsonDecode(response.body)['error'] ??
          'Failed to update payment gateway.';
      print(
          '[ApiService] adminUpdatePaymentGateway failed. Error: $errorMessage');
      throw Exception('Failed to update payment gateway.');
    } else {
      print('[ApiService] Payment gateway updated successfully by admin.');
    }
  }

  Future<void> deletePaymentMethod(String methodId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] deletePaymentMethod: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/payments/methods/$methodId';
    print('[ApiService] Deleting payment method $methodId via $apiUrl');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          '[ApiService] deletePaymentMethod Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to delete payment method';
        print('[ApiService] deletePaymentMethod failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Payment method deleted successfully.');
      }
    } catch (e) {
      print('[ApiService] Error deleting payment method: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> setDefaultPaymentMethod(String methodId) async {
    final token = await _getToken();
    if (token == null) {
      print('[ApiService] setDefaultPaymentMethod: Not authenticated.');
      throw Exception('Not authenticated.');
    }

    final String apiUrl = '$baseUrl/payments/methods/$methodId/set-default';
    print(
        '[ApiService] Setting payment method $methodId as default via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      print(
          '[ApiService] setDefaultPaymentMethod Response Status: ${response.statusCode}, Body: ${response.body}');

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        final errorMessage =
            responseBody['error'] ?? 'Failed to set default payment method';
        print(
            '[ApiService] setDefaultPaymentMethod failed. Error: $errorMessage');
        throw Exception(errorMessage);
      } else {
        print('[ApiService] Payment method set as default successfully.');
      }
    } catch (e) {
      print(
          '[ApiService] Error setting default payment method: ${e.toString()}');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initializePaymentForOrder(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      print(
          '[ApiService] initializePaymentForOrder: Authentication token not found.');
      throw Exception('Authentication token not found.');
    }

    final String apiUrl = '$baseUrl/payments/initialize';
    print('[ApiService] Initializing payment for order $orderId via $apiUrl');
    final payload = {'orderId': orderId};
    print('[ApiService] initializePaymentForOrder Payload: $payload');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      final responseBody = jsonDecode(response.body);
      print(
          '[ApiService] initializePaymentForOrder Response Status: ${response.statusCode}, Body: $responseBody');
      if (response.statusCode == 200) {
        print(
            '[ApiService] Payment initialized successfully. Access code: ${responseBody['accessCode']}');
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to initialize payment';
        print(
            '[ApiService] initializePaymentForOrder failed. Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('[ApiService] Failed to initialize payment: ${e.toString()}');
      throw Exception('Failed to initialize payment: ${e.toString()}');
    }
  }
}
