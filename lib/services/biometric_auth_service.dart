// File: lib/services/biometric_helper.dart
// Purpose: Centralize biometric & secure-storage logic so UI stays clean.

import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BiometricHelper {
  // Use `final` and make inner options const so this compiles across versions.
  static final FlutterSecureStorage _storage = FlutterSecureStorage(
    aOptions: const AndroidOptions(encryptedSharedPreferences: true),
    iOptions:
        const IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _kBiometricEnabled = 'biometric_enabled';
  static const String _kRefreshToken = 'refresh_token';

  final LocalAuthentication _auth = LocalAuthentication();

  /// True if device supports biometrics and user has enrolled at least one.
  Future<bool> canUseBiometrics() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      final enrolled = await _auth.getAvailableBiometrics();
      return supported && canCheck && enrolled.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Optional helper to inspect available biometric types (Face/Touch/etc).
  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const <BiometricType>[];
    }
  }

  /// Ask OS for Face ID / Touch ID.
  Future<bool> authenticate({String reason = 'Unlock with biometrics'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: false, // keep false for explicit user intent each time
          useErrorDialogs: true, // surface system dialogs
        ),
      );
    } catch (_) {
      return false;
    }
  }

  /// Turn the feature on/off (user-controlled).
  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(key: _kBiometricEnabled, value: enabled ? '1' : '0');
    if (!enabled) {
      // Optional hygiene: also clear stored refresh token on disable.
      // await _storage.delete(key: _kRefreshToken);
    }
  }

  Future<bool> isBiometricEnabled() async {
    final v = await _storage.read(key: _kBiometricEnabled);
    return v == '1';
    // Default is 'off' when key absent.
  }

  /// Securely persist refresh token (to support quick-unlock).
  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _kRefreshToken, value: refreshToken);
  }

  Future<String?> getRefreshToken() async {
    return _storage.read(key: _kRefreshToken);
  }

  Future<void> clearRefreshToken() async {
    await _storage.delete(key: _kRefreshToken);
  }
}
