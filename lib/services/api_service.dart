// File: lib/services/api_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart'; // Re-added for BuildContext in Flutter
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Make sure this is imported if using .env for baseUrl
import '../utils/constants.dart';
import '../models/feedback.dart' as app_feedback;
import '../models/location.dart' as app_location;
import '../models/notification.dart';
import '../models/user.dart' as app_user;
import '../models/address_model.dart';
import '../models/system_config_model.dart'; // Import the PLAIN model
import '../models/admin/admin_config_model.dart'
    as admin_model; // Use prefix for admin model
import '../models/place_order_response_model.dart';
import '../models/order.dart' as app_order; // Import the Order model
import '../models/deal_model.dart';
import '../models/chat_thread_model.dart'; // Import the new model
import '../models/driver_stats_model.dart'; // Import the new model
import '../models/driver_profile_model.dart'; // Import the new model
import '../models/admin/dashboard_stats_model.dart'; // Import the new model
import '../models/admin/admin_customer_summary_model.dart';
import '../models/admin/admin_driver_summary_model.dart';
import '../models/admin/admin_order_summary_model.dart'; // Uncommented
import '../models/admin/admin_order_detail_model.dart'; // Corrected to plural
import '../models/admin/admin_run_management_model.dart'
    as admin_run_models; // Corrected to plural
import '../models/admin/admin_driver_detail_model.dart';
import '../models/admin/admin_customer_detail_model.dart';
import '../models/admin/admin_promotion_model.dart';
import '../models/referral_model.dart'; // Import ReferralModel
import '../models/wallet_transaction.dart'; // Ensure wallet transaction model is imported if needed elsewhere
import '../models/admin/admin_referral_summary_model.dart'; // Import AdminReferralSummaryModel
import '../models/payment_method_model.dart'; // Added missing import for PaymentMethodModel

class ApiService {
  final _storage = const FlutterSecureStorage();
  final String baseUrl = dotenv.env['API_BASE_URL'] ??
      'https://primejet-backend.onrender.com/api/v1';

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  // Auth methods
  Future<Map<String, dynamic>> login(String email, String password) async {
    final String apiUrl = '$baseUrl/auth/login';
    print('ApiService: Attempting login to $apiUrl');
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final token = responseBody['token'] as String?;
        final userId = responseBody['userId'] as String?;
        final userName = responseBody['name'] as String?;
        final userRole = responseBody['role'] as String?;
        if (token != null &&
            userId != null &&
            userName != null &&
            userRole != null) {
          return {
            'token': token,
            'userId': userId,
            'name': userName,
            'role': userRole,
            'message': responseBody['message'] ?? 'Login successful.'
          };
        } else {
          throw Exception('Login response missing essential data.');
        }
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Login failed: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception(
          'An unexpected error occurred during login: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'jwt_token');
    print('ApiService: Logged out, token deleted.');
  }

  // User methods
  Future<app_user.User> getMyProfile() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated. Please log in.');

    final String apiUrl = '$baseUrl/users/me';
    print('ApiService: Getting my profile from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // The response body is the user object
        return app_user.User.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Failed to get profile';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error fetching profile: ${e.toString()}');
      rethrow;
    }
  }

  Future<List<AddressModel>> getMyAddresses() async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/addresses';
    print('ApiService: Getting addresses from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
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
      print('ApiService: Error fetching addresses: $e');
      throw Exception('Failed to fetch addresses: ${e.toString()}');
    }
  }

  Future<AddressModel> addAddress(AddressModel address) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/addresses';
    print('ApiService: Creating address via $apiUrl');
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
      if (response.statusCode == 201) {
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to create address: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> deleteAddress(String addressId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/addresses/$addressId';
    print('ApiService: Deleting address $addressId via $apiUrl');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print('ApiService: Delete address successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to delete address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error deleting address $addressId: $e');
      throw Exception('Failed to delete address: ${e.toString()}');
    }
  }

  Future<SystemConfigModel> getSystemConfig() async {
    final token = await _getToken();

    final String apiUrl = '$baseUrl/config'; // Corrected endpoint path
    print('ApiService: Getting system configuration from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Return the plain data model
        return SystemConfigModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to get system configuration');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<String> getOrderPaymentStatus(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Authentication token not found.');

    final String apiUrl = '$baseUrl/orders/$orderId/payment-status';
    print('ApiService: Fetching payment status for order $orderId via $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody['paymentStatus']
            as String; // Expects a string like 'Completed', 'Pending', 'Failed'
      } else {
        final errorMessage = responseBody['message'] ??
            'Failed to fetch payment status'; // Changed from 'error' to 'message'
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('Error fetching payment status: $e');
      rethrow;
    }
  }

  // Order methods
  /// simply creates the order and returns its details without initializing any payment.
  Future<PlaceOrderResponseModel> placeOrder(
      Map<String, dynamic> orderPayload) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated to place order.');
    }
    final String apiUrl = '$baseUrl/orders';
    print('ApiService: Placing order to $apiUrl');

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

      if (response.statusCode == 201) {
        return PlaceOrderResponseModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ?? 'Order placement failed';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('An unexpected error occurred while placing your order.');
    }
  }

  // New method to fetch order by ID for polling
  Future<app_order.Order> fetchOrderById(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('ApiService: Fetching order $orderId from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print(
            'ApiService: Order $orderId fetched successfully. Response: $responseBody');
        return app_order.Order.fromJson(responseBody);
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to fetch order $orderId: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to fetch order $orderId: ${e.toString()}');
    }
  }

  Future<List<app_order.Order>> getMyOrders() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl =
        '$baseUrl/orders/me'; // Assuming an endpoint for user's orders
    print('ApiService: Fetched user orders successfully.');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (responseBody['orders'] as List)
            .map((json) => app_order.Order.fromJson(json))
            .toList();
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to get orders');
      }
    } catch (e) {
      rethrow;
    }
  }

  // !!! IMPORTANT: The client-side confirmOrderPayment method is removed
  // as payment confirmation is now handled securely via Monnify webhooks on the backend.
  // The method was previously commented out, now it's fully removed as per instruction.

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('Not authenticated.');
    }
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('ApiService: Attempting to cancel order $orderId via $apiUrl');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print('ApiService: Order cancel successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to cancel order: ${response.statusCode}';
        print(
            'ApiService: Order cancel failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error cancelling order $orderId: $e');
      throw Exception('Failed to cancel order: ${e.toString()}');
    }
  }

  Future<app_order.Order> getOrderDetails(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/orders/$orderId';
    print('ApiService: Getting order details from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print(
            'ApiService: Order details fetched successfully. Response: $responseBody');
        return app_order.Order.fromJson(responseBody);
      } else {
        final errorMessage =
            (responseBody is Map ? responseBody['error'] : null) ??
                (responseBody is Map ? responseBody['message'] : null) ??
                'Failed to get order details: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to fetch order details: ${e.toString()}');
    }
  }

  Future<List<app_order.Order>> getCustomerConsumptionData() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/orders/me/consumption-data';
    print('ApiService: Getting consumption data from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = responseBody as List<dynamic>? ?? [];
        return ordersJson
            .map((json) =>
                app_order.Order.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception((responseBody as Map<String, dynamic>)['error'] ??
            'Failed to get consumption data');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Initiates a chat session for an order between the current user and a recipient.
  Future<String> initiateChatSession(
      {required String orderId, required String recipientId}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/chat/initiate';
    print(
        'ApiService: Initiating chat for order $orderId with recipient $recipientId');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'orderId': orderId,
          'recipientId': recipientId,
        }),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return responseBody['chatId'] as String;
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to initiate chat session');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the authenticated user's wallet balance and recent transactions.
  Future<Map<String, dynamic>> getWalletDetails() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/wallet';
    print('ApiService: Getting wallet details from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load wallet details');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateChatThread({
    required String chatId,
    required String lastMessage,
    required String senderId,
  }) async {
    final token = await _getToken();
    if (token == null) return;

    final String apiUrl = '$baseUrl/chat/update-thread';
    print('ApiService: Updating chat thread $chatId');

    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'chatId': chatId,
          'lastMessage': lastMessage,
          'senderId': senderId,
        }),
      );
    } catch (e) {
      print('ApiService: Could not update chat thread summary: $e');
    }
  }

  /// Updates the online/offline availability status for the logged-in driver.
  Future<Map<String, dynamic>> updateDriverAvailability(
      bool isAvailable) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated. Please log in.');

    final String apiUrl = '$baseUrl/users/driver/availability';
    print(
        'ApiService: Updating driver availability to $isAvailable via $apiUrl');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'isAvailableOnline': isAvailable}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { message, driver }
        return responseBody;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to update availability';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error updating availability: ${e.toString()}');
      rethrow;
    }
  }

  /// Fetches performance statistics for the currently authenticated driver.
  Future<DriverStatsModel> getDriverStats({String period = 'allTime'}) async {
    final token = await _getToken();
    if (token == null)
      return DriverStatsModel
          .empty(); // Changed: Return empty model if not auth'd

    // Changed: API URL to match working version
    final uri = Uri.parse('$baseUrl/users/me/stats')
        .replace(queryParameters: {'period': period});
    print('ApiService: Getting driver stats from $uri');
    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode == 200) {
        return DriverStatsModel.fromJson(jsonDecode(response.body));
      } else {
        // If endpoint is not found or other error, return a default empty model
        print(
            'ApiService: Failed to load driver stats (${response.statusCode}), returning default.');
        return DriverStatsModel.empty();
      }
    } catch (e) {
      print('ApiService: Error fetching driver stats: $e. Returning default.');
      return DriverStatsModel.empty();
    }
  }

  // Renamed from getDriverProfile() to getMyDriverProfile() for clarity
  Future<DriverProfileModel> getMyDriverProfile() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated. Please log in.');

    final String apiUrl = '$baseUrl/users/me'; // Uses /users/me endpoint
    print('ApiService: Getting current driver profile from $apiUrl');
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return DriverProfileModel.fromJson(responseBody);
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to get profile');
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error fetching driver profile: ${e.toString()}');
      rethrow;
    }
  }

  /// Allows a driver to update the status of a specific stop within a run.
  Future<Map<String, dynamic>> driverUpdateStopStatus({
    required String runId,
    required String stopId,
    required String newStatus,
    String? notes,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl =
        '$baseUrl/runs/driver/runs/$runId/stops/$stopId/update-status';
    print(
        'ApiService: Updating stop $stopId in run $runId to status $newStatus');

    final body = <String, String>{'status': newStatus};
    if (notes != null && notes.isNotEmpty) {
      body['notes'] = notes;
    }

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

      if (response.statusCode == 200) {
        return responseBody; // Assuming backend returns { message, ... }
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to update stop status');
      }
    } catch (e) {
      print('ApiService: Error updating stop status: ${e.toString()}');
      rethrow;
    }
  }

  Future<admin_run_models.AdminActiveRunDetailModel> adminCreateRunFromOrders(
      List<String> orderIds) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/runs/admin/create-batch';
    print('ApiService: Creating run from orders: $orderIds');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'orderIds': orderIds}),
      );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 201) {
        // Assuming the backend returns the newly created run object
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody);
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to create run');
      }
    } catch (e) {
      print('ApiService: Error creating run from batch: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> endRun(String runId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl =
        '$baseUrl/runs/driver/runs/$runId/end'; // Assuming this endpoint
    print('ApiService: Ending run $runId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        // Assuming the body is empty or requires specific data, adjust as needed
        // body: jsonEncode({}),
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody; // Assuming backend returns { message, ... }
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to end run');
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createStripePaymentIntent(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Authentication token not found.');

    final String apiUrl = '$baseUrl/payments/stripe/intent';
    print(
        'ApiService: Creating Stripe Payment Intent for order $orderId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'orderId': orderId}),
      );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print(
            'ApiService: Stripe Payment Intent created successfully: $responseBody');
        if (responseBody['clientSecret'] == null) {
          throw Exception('Client secret not found in PaymentIntent response.');
        }
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create Stripe Payment Intent: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error creating Stripe Payment Intent: $e');
      throw Exception('Failed to create payment intent: ${e.toString()}');
    }
  }

  /// Sends a confirmed PaymentMethod ID from a specific gateway to be saved.
  Future<PaymentMethodModel> attachPaymentMethod({
    required String stripePaymentMethodId,
    required String gateway,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/payments/attach-method';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({
          'paymentMethodId': stripePaymentMethodId,
          'gateway': gateway,
        }),
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 201) {
        return PaymentMethodModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to save payment method');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final String apiUrl = '$baseUrl/auth/register/customer';
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
      if (response.statusCode == 201) {
        return responseBody;
      } else {
        throw Exception(
            responseBody['error'] ?? 'Customer registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Verifies the OTP for a given email address.
  Future<Map<String, dynamic>> verifyOtp({
    required String email,
    required String otp,
  }) async {
    final String apiUrl = '$baseUrl/auth/verify-otp';
    print('ApiService: Verifying OTP for $email at $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'otp': otp}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody; // Expects { message: '...' }
      } else {
        final errorMessage = responseBody['error'] ?? 'OTP verification failed';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error during OTP verification: $e');
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
        'ApiService: Attempting admin self-registration to $apiUrl for $email');

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

      if (response.statusCode == 201) {
        print(
            'ApiService: Admin self-registration successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Admin registration failed: ${response.statusCode}');
        print(
            'ApiService: Admin self-registration failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('ApiService: Network error during admin self-registration: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('ApiService: HTTP error during admin self-registration: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('ApiService: Unexpected error during admin self-registration: $e');
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
      throw Exception('Admin not authenticated. Cannot create user.');
    }

    print('ApiService: Admin creating user ($role) via $apiUrl for $email');

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

      if (response.statusCode == 201) {
        print(
            'ApiService: User creation by admin successful. Response: $responseBody');
        return app_user.User.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            'Admin user creation failed: ${response.statusCode}';
        print(
            'ApiService: Admin user creation failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('ApiService: Network error during admin user creation: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('ApiService: HTTP error during admin user creation: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('ApiService: Unexpected error during admin user creation: $e');
      throw Exception(
          'An unexpected error occurred during user creation: ${e.toString()}');
    }
  }

  /// Fetches the main dashboard statistics for the admin panel.
  Future<DashboardStatsModel> getAdminDashboardStats() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/admin/dashboard-stats';
    print('ApiService: Getting admin dashboard stats from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return DashboardStatsModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load dashboard stats');
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error fetching admin stats: ${e.toString()}');
      rethrow;
    }
  }

  /// Fetches a paginated and searchable list of all customers for the admin panel.
  Future<Map<String, dynamic>> adminGetCustomers({
    int page = 1,
    int limit = 15,
    String? searchQuery,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final queryParams = <String, String>{
      'role': 'customer', // Hardcode the role for this specific function
      'page': page.toString(),
      'limit': limit.toString(),
    };

    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }

    final uri =
        Uri.parse('$baseUrl/users/admin').replace(queryParameters: queryParams);
    print('ApiService: Getting admin customers from $uri');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // Backend returns { users: [...], currentPage, totalPages, totalUsers }
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
        throw Exception(responseBody['error'] ?? 'Failed to load customers');
      }
    } catch (e) {
      print('ApiService: Error fetching admin customers: ${e.toString()}');
      rethrow;
    }
  }

  /// Assigns a driver to a single order. Admin only.
  Future<void> adminAssignDriver(String orderId, String driverId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/orders/admin/$orderId/assign-driver';
    print('ApiService: Admin assigning driver $driverId to order $orderId');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'driverId': driverId}),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to assign driver');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches the detailed profile of a specific driver for an admin.
  Future<AdminDriverDetailModel> adminGetDriverDetails(String driverId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/users/admin/$driverId';
    print('ApiService: Getting driver details for $driverId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // The service is now expected to return the enhanced object with stats
        return AdminDriverDetailModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load driver details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates the account status (e.g., Active, Suspended) of any user by an admin.
  Future<void> adminUpdateUserStatus(String userId, String status) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/users/admin/$userId/status';
    print('ApiService: Updating user $userId status to $status');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'status': status}),
      );
      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to update user status');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Forces a driver's availability status (online/offline) by an admin.
  Future<void> adminSetDriverAvailability(
      String driverId, bool isAvailable) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/users/admin/$driverId';
    print(
        'ApiService: Admin setting availability for driver $driverId to $isAvailable');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'isAvailableOnline': isAvailable}),
      );
      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to update availability');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<admin_run_models.AdminActiveRunDetailModel> adminGetRunDetails(
      String runId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/runs/$runId';
    print('ApiService: Getting admin run details for $runId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody);
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to load run details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches pending runs (batches) for the admin run management screen.
  Future<List<admin_run_models.AdminPickupBatchSummary>>
      adminGetPendingBatches() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/runs/admin/pending-batches';
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (responseBody as List)
            .map((data) =>
                admin_run_models.AdminPickupBatchSummary.fromJson(data))
            .toList();
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load pending batches');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fetches active runs for the admin run management screen.
  Future<List<admin_run_models.AdminActiveRunInfo>> adminGetActiveRuns() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/runs/admin/active';
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return (responseBody as List)
            .map((data) => admin_run_models.AdminActiveRunInfo.fromJson(data))
            .toList();
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to load active runs');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Fetches unassigned orders (a specific subset of all orders).
  // Integrated logic from the non-working version.
  Future<List<admin_run_models.AdminUnassignedOrder>>
      adminGetUnassignedOrders() async {
    try {
      final Map<String, dynamic> response =
          await adminGetOrders(status: "Order Confirmed");
      final List<AdminOrderSummaryModel> orders =
          response['orders'] as List<AdminOrderSummaryModel>? ?? [];
      return orders
          .map((order) =>
              admin_run_models.AdminUnassignedOrder.fromOrderSummary(order))
          .toList();
    } catch (e) {
      print('ApiService: Could not fetch unassigned orders. Error: $e');
      return [];
    }
  }

  /// Fetches a paginated and filtered list of all orders for the admin panel.
  // This method was missing from the provided 'working' file but present and needed in the 'non-working' one.
  Future<Map<String, dynamic>> adminGetOrders({
    int page = 1,
    int limit = 15,
    String? status,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

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

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
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
        throw Exception(responseBody['error'] ?? 'Failed to load orders');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetches available drivers and returns the correct, aliased type.
  Future<List<admin_run_models.AvailableDriverForMap>>
      adminGetAvailableDrivers() async {
    try {
      // Kept 'limit: 100' from the non-working version as a functional preference
      final Map<String, dynamic> response =
          await adminGetDrivers(isAvailableOnline: true, limit: 100);
      final List<AdminDriverSummaryModel> drivers =
          response['drivers'] as List<AdminDriverSummaryModel>? ?? [];
      return drivers
          .map((driver) =>
              admin_run_models.AvailableDriverForMap.fromDriverSummary(driver))
          .toList();
    } catch (e) {
      print('ApiService: Could not fetch available drivers. Error: $e');
      return [];
    }
  }

  // Renamed from adminAssignRunToDriver and consolidated logic based on working file
  Future<void> adminAssignDriverToRun(String runId, String driverId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl =
        '$baseUrl/runs/admin/$runId/assign-driver'; // Uses /admin and POST
    try {
      final response = await http.post(
        // Uses POST method
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'driverId': driverId}),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to assign driver to run');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestPasswordReset(String email) async {
    final String apiUrl = '$baseUrl/auth/request-password-reset';
    print('ApiService: Requesting password reset for $email to $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print(
            'ApiService: Password reset request successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Password reset request failed: ${response.statusCode}');
        print(
            'ApiService: Password reset request failed. Status: ${response.statusCode}, Error: $errorMessage, Body: $responseBody');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('ApiService: Network error during password reset request: $e');
      throw Exception(
          'Network error: Please check your connection and ensure local server is running.');
    } on HttpException catch (e) {
      print('ApiService: HTTP error during password reset request: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('ApiService: Unexpected error during password reset request: $e');
      throw Exception(
          'An unexpected error occurred while requesting password reset: ${e.toString()}');
    }
  }

  /// Fetches the authenticated user's referral information.
  /// If no referral info exists, the backend will create and return it.
  Future<Map<String, dynamic>> getReferralInfo() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    // Note: The backend endpoint is `/referrals`, no customerId in path.
    // The `authMiddleware` identifies the user.
    final String apiUrl = '$baseUrl/referrals';
    print('ApiService: Getting referral info from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load referral info');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> resetPassword(
      String token, String newPassword) async {
    final String apiUrl = '$baseUrl/auth/reset-password';
    print('ApiService: Attempting to reset password with token to $apiUrl');

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

      if (response.statusCode == 200) {
        print('ApiService: Password reset successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Password reset failed: ${response.statusCode}');
        print(
            'ApiService: Password reset failed. Status: ${response.statusCode}, Error: $errorMessage, Body: $responseBody');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('ApiService: Network error during password reset: $e');
      throw Exception('Network error: Please check your connection.');
    } on HttpException catch (e) {
      print('ApiService: HTTP error during password reset: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('ApiService: Unexpected error during password reset: $e');
      throw Exception(
          'An unexpected error occurred while resetting password: ${e.toString()}');
    }
  }

  Future<List<DealModel>> getActivePromotions() async {
    final String apiUrl = '$baseUrl/promotions/active';
    print('ApiService: Getting active promotions from $apiUrl');
    try {
      final response = await http.get(Uri.parse(apiUrl));
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> promotionsJson =
            responseBody as List<dynamic>? ?? [];
        return promotionsJson
            .map((json) =>
                DealModel.fromBackendPromotion(json as Map<String, dynamic>))
            .toList();
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to get active promotions: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error fetching active promotions: $e');
      throw Exception('Failed to fetch promotions: ${e.toString()}');
    }
  }

  // --- PROMOTIONS ---

  /// Fetches all promotions for the admin panel.
  Future<List<AdminPromotionModel>> adminGetPromotions() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/promotions';

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        // The backend returns a paginated object { promotions: [...] }
        final List<dynamic> promotionsJson =
            responseBody['promotions'] as List<dynamic>? ?? [];
        return promotionsJson
            .map((data) => AdminPromotionModel.fromJson(data))
            .toList();
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to load promotions');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a new promotion.
  Future<void> adminCreatePromotion(Map<String, dynamic> promotionData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/promotions';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(promotionData),
      );
      if (response.statusCode != 201) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to create promotion');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing promotion (used for both full edits and status toggles).
  Future<void> adminUpdatePromotion(
      String promoId, Map<String, dynamic> updateData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/promotions/$promoId';

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(updateData),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to update promotion');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a promotion.
  Future<void> adminDeletePromotion(String promoId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/promotions/$promoId';

    try {
      final response = await http.delete(Uri.parse(apiUrl),
          headers: {'Authorization': 'Bearer $token'});
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to delete promotion');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- REFINED & CORRECTED getCustomerOrders METHOD ---
  Future<Map<String, dynamic>> getCustomerOrders({
    String? status,
    int page = 1,
    int limit = 10,
    String? sortBy = '-orderDate',
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final queryParameters = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      queryParameters['status'] = status;
    }
    if (sortBy != null && sortBy.isNotEmpty) {
      queryParameters['sortBy'] = sortBy; // Corrected variable name
    }

    final uri =
        Uri.parse('$baseUrl/orders').replace(queryParameters: queryParameters);
    print('ApiService: Getting customer orders from $uri');

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        final List<dynamic> ordersJson =
            responseBody['orders'] as List<dynamic>? ?? [];
        final List<app_order.Order> typedOrders = ordersJson
            .map((json) =>
                app_order.Order.fromJson(json as Map<String, dynamic>))
            .toList();

        return {
          'orders': typedOrders, // Return a typed list
          'currentPage': responseBody['currentPage'] as int? ?? 1,
          'totalPages': responseBody['totalPages'] as int? ?? 1,
          'totalOrders': responseBody['totalOrders'] as int? ?? 0,
        };
      } else {
        final errorMessage = (responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch orders: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error fetching orders: $e');
      // Rethrowing the original error can be more informative
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
    print('ApiService: Attempting driver registration to $apiUrl for $email');

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

      if (response.statusCode == 201) {
        print(
            'ApiService: Driver registration successful. Response: $responseBody');
        return responseBody;
      } else {
        final errorMessage = responseBody['error'] ??
            (responseBody['message'] ??
                'Driver registration failed: ${response.statusCode}');
        print(
            'ApiService: Driver registration failed. Status: ${response.statusCode}, Error: $errorMessage');
        throw Exception(errorMessage);
      }
    } on SocketException catch (e) {
      print('ApiService: Network error during driver registration: $e');
      throw Exception(
          'Network error: Please check your connection and ensure local server is running.');
    } on HttpException catch (e) {
      print('ApiService: HTTP error during driver registration: $e');
      throw Exception('HTTP error: Could not connect to the server.');
    } catch (e) {
      print('ApiService: Unexpected error during driver registration: $e');
      throw Exception(
          'An unexpected error occurred during driver registration: ${e.toString()}');
    }
  }

  // This method is confirmed to be correct from the previous analysis.
  Future<List<admin_run_models.AdminActiveRunInfo>> getAssignedRuns() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/runs/driver/assigned-runs';
    print('ApiService: Fetching assigned runs for driver from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> runsJson = responseBody as List<dynamic>? ?? [];
        return runsJson
            .map((json) => admin_run_models.AdminActiveRunInfo.fromJson(
                json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception((responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch assigned runs');
      }
    } catch (e) {
      print('ApiService: Error fetching assigned runs: ${e.toString()}');
      rethrow;
    }
  }

  // To get a specific run's details
  Future<admin_run_models.AdminActiveRunDetailModel> getRunDetails(
      String runId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl =
        '$baseUrl/runs/$runId'; // Assuming an endpoint like /runs/:runId
    print('ApiService: Fetching details for run $runId');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return admin_run_models.AdminActiveRunDetailModel.fromJson(
            responseBody as Map<String, dynamic>);
      } else {
        throw Exception((responseBody as Map<String, dynamic>)['error'] ??
            'Failed to fetch run details');
      }
    } catch (e) {
      throw Exception('Error fetching run details: ${e.toString()}');
    }
  }

  // Fetches the complete details for a single order for an admin.
  Future<AdminOrderDetailModel> adminGetOrderDetails(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/orders/$orderId';
    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return AdminOrderDetailModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load order details');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Updates the status of an order. Admin only.
  Future<void> adminUpdateOrderStatus(String orderId, String newStatus,
      {String? notes}) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/orders/admin/$orderId/status';

    final payload = <String, String>{'status': newStatus};
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(payload),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to update order status');
      }
    } catch (e) {
      rethrow;
    }
  }

  // Adds an internal note to an order. Admin only.
  Future<void> adminAddNoteToOrder(String orderId, String noteText) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    // Assumes new backend endpoint POST /api/v1/orders/admin/:orderId/notes
    final String apiUrl = '$baseUrl/orders/admin/$orderId/notes';

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode({'note': noteText}),
      );
      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? 'Failed to add note');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ChatThreadModel>> getChatThreads() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/chat/my-threads';
    print('ApiService: Getting chat threads from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> threadsJson = responseBody as List<dynamic>? ?? [];
        return threadsJson
            .map((json) =>
                ChatThreadModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to load messages');
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error fetching chat threads: ${e.toString()}');
      rethrow;
    }
  }

  // This method is also confirmed.
  Future<Map<String, dynamic>> acceptRun(String runId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    // The backend route uses :batchId, but it corresponds to our runId.
    final String apiUrl = '$baseUrl/runs/driver/runs/$runId/accept';
    print('ApiService: Accepting run $runId via $apiUrl');

    try {
      final response = await http.post(Uri.parse(apiUrl), headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      });
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody; // Returns { message, run }
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to accept run');
      }
    } catch (e) {
      print('ApiService: Error accepting run: ${e.toString()}');
      rethrow;
    }
  }

  Future<AddressModel> setDefaultAddress(String addressId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/addresses/$addressId/default';
    print('ApiService: Setting default address $addressId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        print(
            'ApiService: Set default address successful. Response: $responseBody');
        // The backend returns a complex object, but we only need the address part
        return AddressModel.fromJson(
            responseBody['address'] as Map<String, dynamic>);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to set default address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      print('ApiService: Error setting default address $addressId: $e');
      throw Exception('Failed to set default address: ${e.toString()}');
    }
  }

  Future<AddressModel> createAddress(Map<String, dynamic> addressData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/addresses';
    print('ApiService: Creating address via $apiUrl');
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
      if (response.statusCode == 201) {
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to create address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to create address: ${e.toString()}');
    }
  }

  Future<AddressModel> updateAddress(
      String addressId, Map<String, dynamic> addressData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/addresses/$addressId';
    print('ApiService: Updating address $addressId via $apiUrl');
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
      if (response.statusCode == 200) {
        return AddressModel.fromJson(responseBody);
      } else {
        final errorMessage = responseBody['error'] ??
            responseBody['message'] ??
            'Failed to update address: ${response.statusCode}';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to update address: ${e.toString()}');
    }
  }

  /// Updates the system configuration. Admin only.
  /// Takes the admin-specific model and converts it to JSON.
  Future<void> updateSystemConfig(admin_model.SystemConfigModel config) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/config'; // Corrected endpoint path
    print('ApiService: Updating system configuration at $apiUrl');

    try {
      final response = await http.put(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        // The toJson() method on the admin model correctly extracts controller text
        body: jsonEncode(config.toJson()),
      );

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to update configuration');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<List<app_user.User>> getUsers() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.get(
      Uri.parse('$baseUrl/users/admin'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = jsonDecode(response.body);
      final List<dynamic> usersList = data['users'];
      return usersList.map((json) => app_user.User.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch users: ${response.body}');
    }
  }

  Future<void> deleteUser(String userId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.delete(
      Uri.parse('$baseUrl/users/admin/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to delete user';
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  Future<void> updateUserRole(String userId, String role) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.put(
      Uri.parse('$baseUrl/users/admin/$userId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'role': role}),
    );
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to update role';
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  /// Updates the currently authenticated user's profile.
  /// The `updateData` is a Map containing the fields to update, e.g., {'phone': '12345'}.
  Future<app_user.User> updateProfile(Map<String, dynamic> updateData) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated. Please log in.');

    final String apiUrl = '$baseUrl/users/me';
    print('ApiService: Updating my profile at $apiUrl');

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

      if (response.statusCode == 200) {
        // The backend returns the updated user object in the 'user' field of the response
        return app_user.User.fromJson(responseBody['user']);
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to update profile';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error updating profile: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> processPayment(
      String orderId, double amount, String transactionId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/payment'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({
        'orderId': orderId,
        'amount': (amount * 100).toInt(),
        'transactionId': transactionId
      }),
    );
    if (response.statusCode != 200) {
      final responseBody = jsonDecode(response.body);
      final errorMessage =
          responseBody['error'] ?? responseBody['message'] ?? 'Payment failed';
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  // Fetches all notifications for the currently authenticated user.
  Future<List<NotificationModel>> getNotifications() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/notifications';
    print('ApiService: Fetching notifications from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> notificationsJson =
            responseBody as List<dynamic>? ?? [];
        return notificationsJson
            .map((json) =>
                NotificationModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception((responseBody as Map<String, dynamic>)['error'] ??
            'Failed to load notifications');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Marks a single notification as read on the backend.
  Future<void> markNotificationAsRead(String notificationId) async {
    final token = await _getToken();
    if (token == null) return;
    final String apiUrl = '$baseUrl/notifications/$notificationId/read';
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print(
          'ApiService: Could not mark notification $notificationId as read: $e');
      // Optionally rethrow if you want to handle the error in the UI
    }
  }

  /// Marks all of the user's notifications as read.
  Future<void> markAllNotificationsAsRead() async {
    final token = await _getToken();
    if (token == null) return;
    final String apiUrl = '$baseUrl/notifications/mark-all-read';
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print('ApiService: Could not mark all notifications as read: $e');
    }
  }

  /// Deletes all of the user's notifications.
  Future<void> clearAllNotifications() async {
    final token = await _getToken();
    if (token == null) return;
    final String apiUrl = '$baseUrl/notifications/all';
    try {
      await http.delete(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      print('ApiService: Could not clear all notifications: $e');
    }
  }

  Future<List<app_location.Location>> getLocationHistory(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.get(
      Uri.parse('$baseUrl/orders/$orderId/location-history'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
    );
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => app_location.Location.fromJson(json)).toList();
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to fetch location history';
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  /// Fetches a paginated and filtered list of all drivers for the admin panel.
  Future<Map<String, dynamic>> adminGetDrivers({
    int page = 1,
    int limit = 15,
    String? searchQuery,
    String? accountStatus, // e.g., "Active", "Suspended"
    bool? isAvailableOnline, // e.g., true for "Online", false for "Offline"
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

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
    print('ApiService: Getting admin drivers from $uri');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
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
        throw Exception(responseBody['error'] ?? 'Failed to load drivers');
      }
    } catch (e) {
      print('ApiService: Error fetching admin drivers: ${e.toString()}');
      rethrow;
    }
  }

  /// Fetches the detailed profile of a specific customer for an admin.
  Future<AdminCustomerDetailModel> adminGetCustomerDetails(
      String customerId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/users/admin/$customerId';
    print('ApiService: Getting customer details for $customerId from $apiUrl');

    try {
      final response = await http
          .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        // Assumes backend service is enhanced to return the full detail model
        return AdminCustomerDetailModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to load customer details');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Triggers a password reset email for a given user email address.
  Future<void> adminTriggerPasswordReset(String email) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    // This endpoint is public but we call it as an authenticated admin action
    final String apiUrl = '$baseUrl/auth/request-password-reset';
    print('ApiService: Admin triggering password reset for $email');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to trigger password reset');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> submitFeedback(
      String orderId, app_feedback.Feedback feedback) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final response = await http.post(
      Uri.parse('$baseUrl/orders/$orderId/feedback'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode(feedback.toJson()),
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      final responseBody = jsonDecode(response.body);
      final errorMessage = responseBody['error'] ??
          responseBody['message'] ??
          'Failed to submit feedback';
      throw Exception('$errorMessage: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final String apiUrl = '$baseUrl/auth/google/mobile-signin';
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );
      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(
            responseBody['error'] ?? 'Google Sign-In failed on the server.');
      }
    } catch (e) {
      rethrow;
    }
  }

  // --- REFERRALS (CUSTOMER) ---
  /// Fetches the current user's referral information.
  Future<ReferralModel> getReferralInformation(String customerId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    // Note: The backend endpoint is `/referrals`, no customerId in path.
    // The `authMiddleware` identifies the user.
    final String apiUrl = '$baseUrl/referrals';
    print(
        'ApiService: Getting referral info for customer $customerId from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return ReferralModel.fromJson(responseBody);
      } else {
        throw Exception(
            responseBody['error'] ?? 'Failed to get referral information');
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error fetching referral information: ${e.toString()}');
      rethrow;
    }
  }

  // --- REFERRALS (ADMIN) ---
  /// Fetches a paginated list of all referral records for the admin panel.
  Future<Map<String, dynamic>> adminGetReferrals({
    int page = 1,
    int limit = 10,
    String? searchQuery,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
    };
    if (searchQuery != null && searchQuery.isNotEmpty) {
      queryParams['search'] = searchQuery;
    }

    final uri = Uri.parse('$baseUrl/referrals/admin')
        .replace(queryParameters: queryParams);
    print('ApiService: Getting admin referrals from $uri');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
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
        throw Exception(responseBody['error'] ?? 'Failed to load referrals');
      }
    } catch (e) {
      print('ApiService: Error fetching admin referrals: ${e.toString()}');
      rethrow;
    }
  }

  /// Sends the device's FCM token to the backend to register for push notifications.
  Future<void> registerFcmToken(String token) async {
    final authToken = await _getToken();
    if (authToken == null) {
      print('ApiService: Cannot register FCM token, user not authenticated.');
      return;
    }

    final String apiUrl = '$baseUrl/users/me/fcm-token';
    print('ApiService: Registering FCM token to $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'fcmToken': token}),
      );

      if (response.statusCode != 200) {
        print(
            'ApiService: Failed to register FCM token. Status: ${response.statusCode}, Body: ${response.body}');
      } else {
        print('ApiService: FCM token registered successfully.');
      }
    } catch (e) {
      print('ApiService: Error registering FCM token: $e');
    }
  }

  // --- START OF VOICE CALLING WITH AGORA CHANGES ---
  /// Fetches an Agora RTC token from the backend for initiating a voice call.
  /// This method is part of the API service.
  Future<String> getAgoraToken(String channelName) async {
    final token = await _getToken();
    if (token == null)
      throw Exception('Not authenticated. Cannot get Agora token.');

    final String apiUrl = '$baseUrl/voice/agora-token';
    print(
        'ApiService: Requesting Agora token for channel "$channelName" from $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'channelName': channelName}),
      );

      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final String agoraToken = responseBody['token'] as String;
        print('ApiService: Successfully received Agora token.');
        return agoraToken;
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to get Agora token';
        throw Exception(errorMessage);
      }
    } on SocketException {
      throw Exception('Network error. Please check your connection.');
    } catch (e) {
      print('ApiService: Error getting Agora token: $e');
      rethrow;
    }
  }
  // --- END OF VOICE CALLING WITH AGORA CHANGES ---

  Future<Map<String, dynamic>> adminGetReport({
    required String reportType,
    String period = 'weekly',
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final uri = Uri.parse('$baseUrl/reports').replace(queryParameters: {
      'reportType': reportType,
      'period': period,
    });

    print('ApiService: Getting report from $uri');

    try {
      final response =
          await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        return responseBody;
      } else {
        throw Exception(responseBody['error'] ?? 'Failed to load report');
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> initializeCardTokenization() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/payments/tokenize-card/initialize';
    final response = await http
        .post(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to initialize card tokenization.');
    }
  }

  Future<List<PaymentMethodModel>> getPaymentMethods() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/payments/methods';
    print('ApiService: Getting payment methods from $apiUrl');

    try {
      final response = await http.get(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );
      final responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> methodsJson = responseBody as List<dynamic>? ?? [];
        return methodsJson
            .map((json) =>
                PaymentMethodModel.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw Exception((responseBody as Map<String, dynamic>)['error'] ??
            'Failed to load payment methods');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Creates a SetupIntent using the admin-configured default gateway.
  Future<Map<String, dynamic>> createSetupIntent() async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');
    final String apiUrl = '$baseUrl/payments/setup-intent';
    final response = await http.post(
      Uri.parse(apiUrl),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body); // Returns { clientSecret, gateway }
    } else {
      throw Exception('Failed to initialize card setup');
    }
  }

  // --- NEW ADMIN METHODS ---

  Future<Map<String, dynamic>> adminGetPaymentConfig() async {
    final token = await _getToken();
    if (token == null) throw Exception('Admin not authenticated.');
    final String apiUrl = '$baseUrl/admin/config/payment-gateway';
    final response = await http
        .get(Uri.parse(apiUrl), headers: {'Authorization': 'Bearer $token'});
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch payment configuration.');
    }
  }

  Future<void> adminUpdatePaymentGateway(String gateway) async {
    final token = await _getToken();
    if (token == null) throw Exception('Admin not authenticated.');
    final String apiUrl = '$baseUrl/admin/config/payment-gateway';
    final response = await http.patch(
      Uri.parse(apiUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'gateway': gateway}),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update payment gateway.');
    }
  }

  /// Deletes a saved payment method.
  Future<void> deletePaymentMethod(String methodId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/payments/methods/$methodId';
    print('ApiService: Deleting payment method $methodId');

    try {
      final response = await http.delete(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to delete payment method');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Sets a payment method as the default.
  Future<void> setDefaultPaymentMethod(String methodId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated.');

    final String apiUrl = '$baseUrl/payments/methods/$methodId/set-default';
    print('ApiService: Setting payment method $methodId as default');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode != 200) {
        final responseBody = jsonDecode(response.body);
        throw Exception(
            responseBody['error'] ?? 'Failed to set default payment method');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Initializes a payment on the backend and gets an access_code.
  Future<Map<String, dynamic>> initializePaymentForOrder(String orderId) async {
    final token = await _getToken();
    if (token == null) throw Exception('Authentication token not found.');

    final String apiUrl = '$baseUrl/payments/initialize';
    print('ApiService: Initializing payment for order $orderId via $apiUrl');

    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'orderId': orderId}),
      );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return responseBody; // Expects { accessCode, paymentNeeded }
      } else {
        final errorMessage =
            responseBody['error'] ?? 'Failed to initialize payment';
        throw Exception(errorMessage);
      }
    } catch (e) {
      throw Exception('Failed to initialize payment: ${e.toString()}');
    }
  }
}
