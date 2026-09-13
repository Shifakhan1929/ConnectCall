import 'dart:io';
import 'package:flutter/foundation.dart';

/// Lightweight helper to check internet connectivity without external packages.
class NetworkHelper {
  /// Check if the device has active internet connectivity before starting a call.
  /// Uses a short timeout so UI is never blocked.
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      try {
        final fallback = await InternetAddress.lookup('1.1.1.1')
            .timeout(const Duration(seconds: 3));
        return fallback.isNotEmpty && fallback[0].rawAddress.isNotEmpty;
      } catch (e) {
        debugPrint('[NetworkHelper] Internet connectivity check failed: $e');
        return false;
      }
    }
  }
}
