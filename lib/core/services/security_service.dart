import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecurityService {
  static final SecurityService instance = SecurityService._internal();
  SecurityService._internal();

  final LocalAuthentication _localAuth = LocalAuthentication();

  static const String _keyAppLockEnabled = 'app_lock_enabled';
  static const String _keyBiometricsEnabled = 'biometrics_enabled';
  static const String _keyPasscode = 'app_passcode';

  Future<bool> isAppLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAppLockEnabled) ?? false;
  }

  Future<void> setAppLockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, enabled);
  }

  Future<bool> isBiometricsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricsEnabled) ?? false;
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricsEnabled, enabled);
  }

  Future<bool> hasPasscode() async {
    final prefs = await SharedPreferences.getInstance();
    final pass = prefs.getString(_keyPasscode);
    return pass != null && pass.isNotEmpty;
  }

  Future<bool> verifyPasscode(String entered) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_keyPasscode);
    return stored == entered;
  }

  Future<void> setPasscode(String newPasscode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyPasscode, newPasscode);
    await setAppLockEnabled(true);
  }

  Future<void> removePasscode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyPasscode);
    await setAppLockEnabled(false);
  }

  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics || await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({String reason = 'Authenticate to access SeakScanner'}) async {
    try {
      final canAuth = await canCheckBiometrics();
      if (!canAuth) return false;

      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }
}

