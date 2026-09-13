import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import '../core/constants/agora_constants.dart';
import '../core/utils/permission_helper.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';
import 'call_history_service.dart';

/// CallingService is responsible for the Agora RTC Engine media lifecycle,
/// device audio/video controls, and channel joining/leaving.
///
/// Firestore call history and signaling are kept strictly isolated
/// in [CallHistoryService].
class CallingService {
  static final CallingService _instance = CallingService._internal();
  factory CallingService() => _instance;
  CallingService._internal();

  final CallHistoryService _callHistoryService = CallHistoryService();

  RtcEngine? _engine;
  bool _isInitialized = false;
  bool _isJoined = false;
  bool _isAudioMuted = false;
  bool _isVideoEnabled = false;
  bool _isSpeakerOn = false;
  int? _localUid;
  final Set<int> _remoteUids = {};

  CallModel? _currentCall;

  // Video and user lifecycle callbacks for UI/controllers
  void Function(int remoteUid)? onUserJoinedCallback;
  void Function(int remoteUid, UserOfflineReasonType reason)? onUserOfflineCallback;
  void Function(VideoSourceType source, LocalVideoStreamState state, LocalVideoStreamReason reason)? onLocalVideoStateCallback;
  void Function(int remoteUid, RemoteVideoState state, RemoteVideoStateReason reason, int elapsed)? onRemoteVideoStateCallback;
  void Function(int remoteUid, int width, int height, int elapsed)? onFirstRemoteVideoFrameCallback;

  // Getters
  RtcEngine? get engine => _engine;
  bool get isInitialized => _isInitialized;
  bool get isJoined => _isJoined;
  bool get isAudioMuted => _isAudioMuted;
  bool get isVideoEnabled => _isVideoEnabled;
  bool get isSpeakerOn => _isSpeakerOn;
  int? get localUid => _localUid;
  int? get remoteUid => _remoteUids.isNotEmpty ? _remoteUids.first : null;
  Set<int> get remoteUids => Set.unmodifiable(_remoteUids);
  CallModel? get currentCall => _currentCall;

  /// Clear registered UI video/lifecycle callbacks
  void clearVideoCallbacks() {
    onUserJoinedCallback = null;
    onUserOfflineCallback = null;
    onLocalVideoStateCallback = null;
    onRemoteVideoStateCallback = null;
    onFirstRemoteVideoFrameCallback = null;
  }

  // --------------------------------------------------------------------------
  // Agora RTC Engine Lifecycle
  // --------------------------------------------------------------------------

  /// Initialize Agora RTC Engine with isolated App ID configuration
  Future<bool> initialize({
    String? appId,
    ChannelProfileType profile = ChannelProfileType.channelProfileCommunication,
  }) async {
    if (_isInitialized && _engine != null) {
      return true;
    }

    final effectiveAppId = appId ?? AgoraConstants.defaultAppId;

    // Check for placeholder credentials in development
    if (effectiveAppId.isEmpty || effectiveAppId == 'YOUR_AGORA_APP_ID') {
      debugPrint(
        'Agora notice: Development App ID is not yet configured. '
        'Set your Agora App ID in AgoraConstants or pass it to initialize().',
      );
      return false;
    }

    try {
      debugPrint('[Agora Diagnostic] Initializing Agora RTC Engine with profile: $profile...');
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        RtcEngineContext(
          appId: effectiveAppId,
          channelProfile: profile,
        ),
      );
      debugPrint('[Agora Diagnostic] Agora RTC Engine initialized successfully.');

      _registerEventHandlers();

      debugPrint('[Agora Diagnostic] Calling enableAudio()...');
      await _engine!.enableAudio();
      debugPrint('[Agora Diagnostic] enableAudio() completed.');

      debugPrint('[Agora Diagnostic] Setting default audio route to speakerphone...');
      await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      _isSpeakerOn = true;
      debugPrint('[Agora Diagnostic] Default audio route set to speakerphone (isSpeakerOn: $_isSpeakerOn).');

      debugPrint('[Agora Diagnostic] Setting client role to clientRoleBroadcaster...');
      await _engine!.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      debugPrint('[Agora Diagnostic] Client role set to clientRoleBroadcaster successfully.');

      _isInitialized = true;
      debugPrint('[Agora Diagnostic] Agora engine setup fully initialized.');
      return true;
    } catch (e) {
      debugPrint('[Agora Diagnostic] Engine initialization ERROR: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Register Agora RTC Event Handlers
  void _registerEventHandlers() {
    if (_engine == null) return;

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) async {
          debugPrint(
            '[Agora Diagnostic] onJoinChannelSuccess -> channel: ${connection.channelId}, localUid: ${connection.localUid}, elapsed: ${elapsed}ms',
          );
          _isJoined = true;
          _localUid = connection.localUid;

          // Enable speakerphone safely AFTER successful channel join
          try {
            await _engine?.setEnableSpeakerphone(true);
            _isSpeakerOn = true;
            debugPrint('[Agora Diagnostic] Speakerphone enabled post-join in onJoinChannelSuccess.');
          } catch (e) {
            debugPrint('[Agora Diagnostic] Error enabling speakerphone post-join: $e');
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint(
            '[Agora Diagnostic] onUserJoined -> remoteUid: $remoteUid in channel: ${connection.channelId}, elapsed: ${elapsed}ms',
          );
          _remoteUids.add(remoteUid);
          onUserJoinedCallback?.call(remoteUid);
        },
        onUserOffline: (
          RtcConnection connection,
          int remoteUid,
          UserOfflineReasonType reason,
        ) {
          debugPrint(
            '[Agora Diagnostic] onUserOffline (remote user left) -> remoteUid: $remoteUid left channel: ${connection.channelId} (reason: $reason)',
          );
          _remoteUids.remove(remoteUid);
          onUserOfflineCallback?.call(remoteUid, reason);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint(
            '[Agora Diagnostic] onLeaveChannel -> channel: ${connection.channelId}, duration: ${stats.duration}s',
          );
          _isJoined = false;
          _remoteUids.clear();
        },
        onLocalAudioStateChanged: (
          RtcConnection connection,
          LocalAudioStreamState state,
          LocalAudioStreamReason reason,
        ) {
          debugPrint(
            '[Agora Diagnostic] onLocalAudioStateChanged -> state: $state, reason: $reason',
          );
        },
        onAudioPublishStateChanged: (
          String channel,
          StreamPublishState oldState,
          StreamPublishState newState,
          int elapsed,
        ) {
          debugPrint(
            '[Agora Diagnostic] onAudioPublishStateChanged -> channel: $channel, newState: $newState',
          );
        },
        onUserMuteAudio: (
          RtcConnection connection,
          int remoteUid,
          bool muted,
        ) {
          debugPrint(
            '[Agora Diagnostic] onUserMuteAudio -> remoteUid: $remoteUid, muted: $muted',
          );
        },
        onRemoteAudioStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteAudioState state,
          RemoteAudioStateReason reason,
          int elapsed,
        ) {
          debugPrint(
            '[Agora Diagnostic] onRemoteAudioStateChanged -> remoteUid: $remoteUid, state: $state, reason: $reason',
          );
        },
        onLocalVideoStateChanged: (
          VideoSourceType source,
          LocalVideoStreamState state,
          LocalVideoStreamReason reason,
        ) {
          debugPrint(
            '[Agora Diagnostic] onLocalVideoStateChanged -> source: $source, state: $state, reason: $reason',
          );
          onLocalVideoStateCallback?.call(source, state, reason);
        },
        onRemoteVideoStateChanged: (
          RtcConnection connection,
          int remoteUid,
          RemoteVideoState state,
          RemoteVideoStateReason reason,
          int elapsed,
        ) {
          debugPrint(
            '[Agora Diagnostic] onRemoteVideoStateChanged -> remoteUid: $remoteUid in channel: ${connection.channelId}, state: $state, reason: $reason, elapsed: ${elapsed}ms',
          );
          onRemoteVideoStateCallback?.call(remoteUid, state, reason, elapsed);
        },
        onFirstRemoteVideoFrame: (
          RtcConnection connection,
          int remoteUid,
          int width,
          int height,
          int elapsed,
        ) {
          debugPrint(
            '[Agora Diagnostic] onFirstRemoteVideoFrame -> remoteUid: $remoteUid (${width}x$height) in channel: ${connection.channelId}, elapsed: ${elapsed}ms',
          );
          onFirstRemoteVideoFrameCallback?.call(remoteUid, width, height, elapsed);
        },
        onConnectionStateChanged: (
          RtcConnection connection,
          ConnectionStateType state,
          ConnectionChangedReasonType reason,
        ) {
          debugPrint(
            '[Agora Diagnostic] onConnectionStateChanged -> state: $state, reason: $reason for channel: ${connection.channelId}',
          );
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
            '[Agora Diagnostic] onTokenPrivilegeWillExpire -> channel: ${connection.channelId}',
          );
        },
        onRequestToken: (RtcConnection connection) {
          debugPrint(
            '[Agora Diagnostic] onRequestToken -> Token required/expired for channel: ${connection.channelId}',
          );
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[Agora Diagnostic] onError -> code: $err, message: $msg');
        },
      ),
    );
  }

  /// Join an Agora audio/video channel
  Future<bool> joinChannel({
    required String channelId,
    String? token,
    int uid = 0,
    bool isVideo = true,
  }) async {
    debugPrint('[Agora Diagnostic] joinChannel() initiated (isVideo: $isVideo, requestedUid: $uid)');

    // 1. Request hardware permissions gracefully
    final permissionsGranted =
        await PermissionHelper.requestCallPermissions(isVideo: isVideo);
    debugPrint('[Agora Diagnostic] Microphone/Hardware permissions result: $permissionsGranted');
    if (!permissionsGranted) {
      debugPrint(
        '[Agora Diagnostic] Permission denied: Cannot join channel without required permissions.',
      );
      return false;
    }

    // 2. Ensure engine is initialized
    if (!_isInitialized) {
      debugPrint('[Agora Diagnostic] Engine not yet initialized, calling initialize()...');
      final initSuccess = await initialize();
      if (!initSuccess) {
        debugPrint('[Agora Diagnostic] Cannot join channel: Engine failed to initialize.');
        return false;
      }
    }

    try {
      if (isVideo) {
        debugPrint('[Agora Diagnostic] Video mode enabled: activating Agora video engine & preview...');
        _isVideoEnabled = true;
        await _engine!.enableVideo();
        await enableLocalVideo(true);
        debugPrint('[Agora Diagnostic] Video engine enabled & local camera preview started.');
      } else {
        _isVideoEnabled = false;
        debugPrint('[Agora Diagnostic] Audio-only mode: video engine remains disabled.');
      }

      final effectiveToken = token ?? AgoraConstants.defaultToken;
      // When a development testing token is configured, use the matching testing channel name
      final effectiveChannel = (effectiveToken.isNotEmpty &&
              AgoraConstants.defaultTestingChannel.isNotEmpty)
          ? AgoraConstants.defaultTestingChannel
          : channelId;

      // Prioritize explicit uid if provided (e.g. 1001 or 1002), otherwise fallback to testing UID
      final effectiveUid = uid != 0
          ? uid
          : ((effectiveToken.isNotEmpty && AgoraConstants.defaultTestingUid != 0)
              ? AgoraConstants.defaultTestingUid
              : uid);

      debugPrint(
        '[Agora Diagnostic] Preparing to join Agora channel: "$effectiveChannel" with UID: $effectiveUid (token configured: ${effectiveToken.isNotEmpty})',
      );

      // Enable and configure audio pipeline explicitly for high-clarity voice
      debugPrint('[Agora Diagnostic] Enabling audio pipeline: enableAudio(), enableLocalAudio(true)...');
      await _engine!.enableAudio();
      await _engine!.enableLocalAudio(true);
      await _engine!.muteLocalAudioStream(false);
      _isAudioMuted = false;
      await _engine!.muteAllRemoteAudioStreams(false);
      await _engine!.adjustRecordingSignalVolume(100);
      await _engine!.adjustPlaybackSignalVolume(100);
      debugPrint('[Agora Diagnostic] Audio pipeline ready. Local mute state: $_isAudioMuted');

      // Set default audio route preference safely without hardware activation pre-join
      try {
        await _engine!.setDefaultAudioRouteToSpeakerphone(true);
        debugPrint('[Agora Diagnostic] Pre-join default audio route set to speakerphone preference.');
      } catch (e) {
        debugPrint('[Agora Diagnostic] Notice on pre-join setDefaultAudioRouteToSpeakerphone: $e');
      }

      debugPrint(
        '[Agora Diagnostic] Executing _engine.joinChannel(channel: "$effectiveChannel", uid: $effectiveUid)...',
      );
      await _engine!.joinChannel(
        token: effectiveToken,
        channelId: effectiveChannel,
        uid: effectiveUid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileCommunication,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: isVideo,
          publishMicrophoneTrack: true,
          autoSubscribeAudio: true,
          autoSubscribeVideo: isVideo,
        ),
      );

      _isJoined = true;
      debugPrint('[Agora Diagnostic] joinChannel() call invoked successfully.');
      return true;
    } catch (e) {
      debugPrint('[Agora Diagnostic] joinChannel() ERROR: $e');
      return false;
    }
  }

  /// Leave the current Agora channel
  Future<void> leaveChannel() async {
    if (_engine == null || !_isJoined) return;

    try {
      if (_isVideoEnabled) {
        try {
          await _engine!.stopPreview();
          await _engine!.disableVideo();
        } catch (_) {}
      }
      await _engine!.leaveChannel();
      _isJoined = false;
      _remoteUids.clear();
      _isVideoEnabled = false;
    } catch (e) {
      debugPrint('[Agora Diagnostic] Error leaving Agora channel: $e');
    }
  }

  /// Toggle or set local microphone mute state
  Future<void> muteLocalAudio(bool isMuted) async {
    if (_engine == null) return;

    try {
      await _engine!.muteLocalAudioStream(isMuted);
      _isAudioMuted = isMuted;
      debugPrint('[Agora Diagnostic] muteLocalAudio -> isAudioMuted updated to: $_isAudioMuted');
    } catch (e) {
      debugPrint('[Agora Diagnostic] Error toggling microphone state: $e');
    }
  }

  /// Enable or disable local video stream and camera preview
  Future<void> enableLocalVideo(bool isEnabled) async {
    if (_engine == null) return;

    try {
      if (isEnabled) {
        final cameraGranted = await PermissionHelper.requestCameraPermission();
        if (!cameraGranted) {
          debugPrint('Camera permission denied.');
          return;
        }
        await _engine!.enableVideo();
        await _engine!.startPreview();
        await _engine!.muteLocalVideoStream(false);
      } else {
        await _engine!.muteLocalVideoStream(true);
        await _engine!.stopPreview();
      }
      _isVideoEnabled = isEnabled;
    } catch (e) {
      debugPrint('Error toggling video state: $e');
    }
  }

  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (_engine == null) return;

    try {
      await _engine!.switchCamera();
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  /// Toggle speakerphone output on or off
  Future<void> toggleSpeakerphone(bool enable) async {
    if (_engine == null) return;

    try {
      await _engine!.setEnableSpeakerphone(enable);
      _isSpeakerOn = enable;
      debugPrint('[Agora Diagnostic] toggleSpeakerphone -> isSpeakerOn updated to: $_isSpeakerOn');
    } catch (e) {
      debugPrint('[Agora Diagnostic] Error toggling speakerphone: $e');
    }
  }

  /// Release and dispose Agora RTC Engine resources
  Future<void> dispose() async {
    if (_engine == null) return;

    try {
      if (_isJoined) {
        await leaveChannel();
      }
      if (_isVideoEnabled) {
        try {
          await _engine!.stopPreview();
          await _engine!.disableVideo();
        } catch (_) {}
      }
      clearVideoCallbacks();
      await _engine!.release();
      _engine = null;
      _isInitialized = false;
      _isJoined = false;
      _remoteUids.clear();
      _isVideoEnabled = false;
      debugPrint('Agora RTC Engine successfully disposed.');
    } catch (e) {
      debugPrint('Error disposing Agora RTC Engine: $e');
    }
  }

  // --------------------------------------------------------------------------
  // Call Metadata / Signaling Placeholders (Kept for compatibility)
  // --------------------------------------------------------------------------

  Future<CallModel> makeCall({
    required UserModel caller,
    required UserModel receiver,
    required CallType type,
  }) async {
    _currentCall = CallModel(
      callId: DateTime.now().millisecondsSinceEpoch.toString(),
      callerId: caller.id,
      callerName: caller.name,
      callerAvatar: caller.avatarUrl,
      receiverId: receiver.id,
      receiverName: receiver.name,
      receiverAvatar: receiver.avatarUrl,
      type: type,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
    );
    return _currentCall!;
  }

  Future<void> acceptCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.accepted);
    }
  }

  Future<void> rejectCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.rejected);
    }
  }

  Future<void> endCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.ended);
    }
  }

  void toggleMute({required bool isMuted}) {
    muteLocalAudio(isMuted);
  }

  void toggleCamera({required bool isCameraOff}) {
    enableLocalVideo(!isCameraOff);
  }

  // --------------------------------------------------------------------------
  // Call History Delegations (Delegated to CallHistoryService)
  // --------------------------------------------------------------------------

  Future<List<CallModel>> getCallHistory({
    String? userId,
    CallType? typeFilter,
    String? searchQuery,
    int limit = 50,
  }) {
    return _callHistoryService.getCallHistory(
      userId: userId,
      typeFilter: typeFilter,
      searchQuery: searchQuery,
      limit: limit,
    );
  }

  Stream<List<CallModel>> getCallHistoryStream({
    String? userId,
    CallType? typeFilter,
    String? searchQuery,
    int limit = 50,
  }) {
    return _callHistoryService.getCallHistoryStream(
      userId: userId,
      typeFilter: typeFilter,
      searchQuery: searchQuery,
      limit: limit,
    );
  }
}
