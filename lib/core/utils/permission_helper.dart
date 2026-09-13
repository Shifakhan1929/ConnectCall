import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_theme.dart';

/// Status of call-related hardware permissions
enum CallPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
}

/// Detailed result of permission checks for audio/video calling
class CallPermissionResult {
  final CallPermissionStatus status;
  final bool hasMic;
  final bool hasCamera;
  final String message;

  const CallPermissionResult({
    required this.status,
    required this.hasMic,
    required this.hasCamera,
    required this.message,
  });

  bool get isGranted => status == CallPermissionStatus.granted;
  bool get isPermanentlyDenied =>
      status == CallPermissionStatus.permanentlyDenied;
  bool get isDenied => status == CallPermissionStatus.denied;
}

class PermissionHelper {
  /// Request microphone permission for audio calling (returns boolean for compatibility)
  static Future<bool> requestMicrophonePermission() async {
    final result = await requestMicrophone();
    return result.isGranted;
  }

  /// Request microphone permission with detailed status result
  static Future<CallPermissionResult> requestMicrophone() async {
    try {
      final status = await Permission.microphone.status;
      if (status.isGranted || status.isLimited) {
        return const CallPermissionResult(
          status: CallPermissionStatus.granted,
          hasMic: true,
          hasCamera: false,
          message: 'Microphone permission granted.',
        );
      }

      if (status.isPermanentlyDenied) {
        return const CallPermissionResult(
          status: CallPermissionStatus.permanentlyDenied,
          hasMic: false,
          hasCamera: false,
          message:
              'Microphone permission is permanently denied. Please enable it in device App Settings to make calls.',
        );
      }

      final result = await Permission.microphone.request();
      if (result.isGranted || result.isLimited) {
        return const CallPermissionResult(
          status: CallPermissionStatus.granted,
          hasMic: true,
          hasCamera: false,
          message: 'Microphone permission granted.',
        );
      } else if (result.isPermanentlyDenied) {
        return const CallPermissionResult(
          status: CallPermissionStatus.permanentlyDenied,
          hasMic: false,
          hasCamera: false,
          message:
              'Microphone permission was permanently denied. Please enable it in device App Settings to place calls.',
        );
      } else {
        return const CallPermissionResult(
          status: CallPermissionStatus.denied,
          hasMic: false,
          hasCamera: false,
          message: 'Microphone permission is required to make calls.',
        );
      }
    } catch (e) {
      debugPrint('Error requesting microphone permission: $e');
      return CallPermissionResult(
        status: CallPermissionStatus.denied,
        hasMic: false,
        hasCamera: false,
        message: 'Could not request microphone permission: $e',
      );
    }
  }

  /// Request camera permission for video calling (returns boolean for compatibility)
  static Future<bool> requestCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      if (status.isGranted || status.isLimited) {
        return true;
      }

      final result = await Permission.camera.request();
      return result.isGranted || result.isLimited;
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      return false;
    }
  }

  /// Request both microphone and camera permissions with detailed status result
  static Future<CallPermissionResult> requestVideoCallPermissions() async {
    final micResult = await requestMicrophone();
    if (!micResult.isGranted) {
      return micResult;
    }

    try {
      final camStatus = await Permission.camera.status;
      if (camStatus.isGranted || camStatus.isLimited) {
        return const CallPermissionResult(
          status: CallPermissionStatus.granted,
          hasMic: true,
          hasCamera: true,
          message: 'Camera and microphone permissions granted.',
        );
      }

      if (camStatus.isPermanentlyDenied) {
        return const CallPermissionResult(
          status: CallPermissionStatus.permanentlyDenied,
          hasMic: true,
          hasCamera: false,
          message:
              'Camera permission is permanently denied. Please enable it in device App Settings to make video calls.',
        );
      }

      final result = await Permission.camera.request();
      if (result.isGranted || result.isLimited) {
        return const CallPermissionResult(
          status: CallPermissionStatus.granted,
          hasMic: true,
          hasCamera: true,
          message: 'Camera and microphone permissions granted.',
        );
      } else if (result.isPermanentlyDenied) {
        return const CallPermissionResult(
          status: CallPermissionStatus.permanentlyDenied,
          hasMic: true,
          hasCamera: false,
          message:
              'Camera permission was permanently denied. Please enable it in device App Settings to make video calls.',
        );
      } else {
        return const CallPermissionResult(
          status: CallPermissionStatus.denied,
          hasMic: true,
          hasCamera: false,
          message: 'Camera permission is required to start a video call.',
        );
      }
    } catch (e) {
      debugPrint('Error requesting camera permission: $e');
      return CallPermissionResult(
        status: CallPermissionStatus.denied,
        hasMic: true,
        hasCamera: false,
        message: 'Could not request camera permission: $e',
      );
    }
  }

  /// Check and request required permissions based on call type (returns CallPermissionResult)
  static Future<CallPermissionResult> checkAndRequestCallPermissions({
    required bool isVideo,
  }) async {
    if (isVideo) {
      return await requestVideoCallPermissions();
    } else {
      return await requestMicrophone();
    }
  }

  /// Request required permissions based on call type (retained boolean API for backward compatibility)
  static Future<bool> requestCallPermissions({required bool isVideo}) async {
    final result = await checkAndRequestCallPermissions(isVideo: isVideo);
    return result.isGranted;
  }

  /// Check if microphone permission is currently granted
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted || status.isLimited;
  }

  /// Check if camera permission is currently granted
  static Future<bool> hasCameraPermission() async {
    final status = await Permission.camera.status;
    return status.isGranted || status.isLimited;
  }

  /// Open device application settings if permission was permanently denied
  static Future<bool> openSettings() async {
    return await openAppSettings();
  }

  /// User-friendly handler for permission denial.
  /// Shows an actionable Dialog when permanently denied, or a floating SnackBar when denied.
  static void handlePermissionResult(
    BuildContext context,
    CallPermissionResult result,
  ) {
    if (result.isGranted) return;

    if (result.isPermanentlyDenied) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.settings_outlined, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Permission Required'),
            ],
          ),
          content: Text(
            result.message,
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(ctx);
                openSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
