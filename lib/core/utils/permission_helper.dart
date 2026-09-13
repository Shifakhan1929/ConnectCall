class PermissionHelper {
  // Placeholder for camera permission check and request
  static Future<bool> requestCameraPermission() async {
    // TODO: Integrate permission_handler package when implementing calls
    return true;
  }

  // Placeholder for microphone permission check and request
  static Future<bool> requestMicrophonePermission() async {
    // TODO: Integrate permission_handler package when implementing calls
    return true;
  }

  // Helper to request both permissions for video calls
  static Future<bool> requestCallPermissions({required bool isVideo}) async {
    final micGranted = await requestMicrophonePermission();
    if (!isVideo) return micGranted;
    final cameraGranted = await requestCameraPermission();
    return micGranted && cameraGranted;
  }
}
