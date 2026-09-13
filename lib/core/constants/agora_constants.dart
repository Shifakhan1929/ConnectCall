/// Configuration constants for Agora Real-Time Communication (RTC) SDK.
///
/// IMPORTANT SECURITY NOTICE:
/// - Never hardcode the Agora App Certificate into source control or client-side code.
/// - The App ID is public, but tokens should ideally be generated dynamically via a secure backend.
/// - Replace [defaultAppId] with your Agora Console App ID for local development/testing.
class AgoraConstants {
  /// Default development Agora App ID.
  /// Obtain from https://console.agora.io/ -> Project Management -> App ID.
  static const String defaultAppId = '8f83e15b1d6949b29090a7eb13278f74';

  /// Development testing channel name for testing with static temporary tokens.
  static const String defaultTestingChannel = 'connectcall';

  /// Caller (Phone 1) testing credentials
  static const int callerTestingUid = 1001;
  static const String callerTestingToken =
      '007eJxTYJCuzO+czqoV7Pxryhzus9vuXLnhsTj+Q5F98IdpPHOd35kqMFikWRinGpomGaaYWZpYJhlZGlgaJJqnJhkaG5lbpJmbPN6zLKshkJEhc5ojMxMDIxiC+NwMyfl5eanJJcmJOTkMDExwCRYGQwMDQwB/EiRG';

  /// Receiver (Phone 2) testing credentials (generated for channel: connectcall, UID: 1002)
  static const int receiverTestingUid = 1002;
  static const String receiverTestingToken = '007eJxTYGiZPNOCM/J3ze2JehHLnro4e/rLr/xdISDgUNC5Y7Oh5BEFBos0C+NUQ9MkwxQzSxPLJCNLA0uDRPPUJENjI3OLNHMT0QPLshoCGRmUFvexMjEwgiGIz82QnJ+Xl5pckpyYk8PAwASXYGEwNDAwAgDEJiIB';

  /// Default fallback token & UID
  static const String defaultToken = callerTestingToken;
  static const int defaultTestingUid = callerTestingUid;

  /// Default channel prefix or name
  static const String defaultChannelPrefix = 'connectcall_';
}
