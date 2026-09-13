import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import '../../core/constants/agora_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../services/call_signaling_service.dart';
import '../../services/calling_service.dart';
import '../../widgets/call_button.dart';

/// VideoCallingScreen provides full-screen 1-to-1 video calling with Agora RTC.
///
/// Displays remote peer video as the primary full-screen view, a floating local
/// camera preview in the upper right, participant metadata, connection status,
/// and in-call media controls (mute, camera toggle, switch camera, end call).
class VideoCallingScreen extends StatefulWidget {
  final CallModel call;
  final bool isCaller;

  const VideoCallingScreen({
    super.key,
    required this.call,
    required this.isCaller,
  });

  @override
  State<VideoCallingScreen> createState() => _VideoCallingScreenState();
}

class _VideoCallingScreenState extends State<VideoCallingScreen> {
  final CallingService _callingService = CallingService();
  final CallSignalingService _callSignalingService = CallSignalingService();

  StreamSubscription<CallModel?>? _callSubscription;
  Timer? _durationTimer;

  VideoViewController? _localController;
  VideoViewController? _remoteController;
  int? _remoteControllerUid;

  int? _remoteUid;
  bool _isConnected = false;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isEnding = false;
  bool _isRemoteVideoActive = false;
  int _callDurationSeconds = 0;
  String _statusText = 'Connecting...';

  String get _remotePartyName => widget.isCaller
      ? widget.call.receiverName
      : widget.call.callerName;

  String get _remotePartyAvatar => widget.isCaller
      ? (widget.call.receiverAvatar ?? '')
      : (widget.call.callerAvatar ?? '');

  @override
  void initState() {
    super.initState();
    _statusText = widget.isCaller ? 'Calling...' : 'Connecting...';
    _setupVideoCallbacks();
    _initializeAndJoin();
    _listenToCallState();
  }

  /// Register Agora video event callbacks with CallingService
  void _setupVideoCallbacks() {
    _callingService.onUserJoinedCallback = (remoteUid) {
      debugPrint('[VideoCallingScreen] onUserJoinedCallback -> $remoteUid');
      if (mounted) {
        setState(() {
          _remoteUid = remoteUid;
          _isConnected = true;
          _statusText = 'Connected';
        });
        _initRemoteController(remoteUid);
        _startTimer();
      }
    };

    _callingService.onUserOfflineCallback = (remoteUid, reason) {
      debugPrint('[VideoCallingScreen] onUserOfflineCallback -> $remoteUid (reason: $reason)');
      if (mounted) {
        setState(() {
          if (_remoteUid == remoteUid) {
            _remoteUid = null;
            _isRemoteVideoActive = false;
            _remoteController?.dispose();
            _remoteController = null;
            _remoteControllerUid = null;
          }
        });
        _handleCallTerminated('Call Ended');
      }
    };

    _callingService.onLocalVideoStateCallback = (source, state, reason) {
      debugPrint('[VideoCallingScreen] onLocalVideoStateCallback -> source: $source, state: $state');
      if (mounted) {
        if (state == LocalVideoStreamState.localVideoStreamStateCapturing ||
            state == LocalVideoStreamState.localVideoStreamStateEncoding) {
          _initLocalController();
        }
      }
    };

    _callingService.onRemoteVideoStateCallback = (remoteUid, state, reason, elapsed) {
      debugPrint('[VideoCallingScreen] onRemoteVideoStateCallback -> uid: $remoteUid, state: $state');
      if (mounted) {
        final isActive = state == RemoteVideoState.remoteVideoStateDecoding ||
            state == RemoteVideoState.remoteVideoStateStarting;
        setState(() {
          _remoteUid = remoteUid;
          _isRemoteVideoActive = isActive;
        });
        if (isActive) {
          _initRemoteController(remoteUid);
        }
      }
    };

    _callingService.onFirstRemoteVideoFrameCallback = (remoteUid, width, height, elapsed) {
      debugPrint('[VideoCallingScreen] onFirstRemoteVideoFrameCallback -> uid: $remoteUid (${width}x$height)');
      if (mounted) {
        setState(() {
          _remoteUid = remoteUid;
          _isRemoteVideoActive = true;
          if (!_isConnected) {
            _isConnected = true;
            _statusText = 'Connected';
            _startTimer();
          }
        });
        _initRemoteController(remoteUid);
      }
    };
  }

  /// Initialize Agora engine and join video channel
  Future<void> _initializeAndJoin() async {
    try {
      final roleToken = widget.isCaller
          ? (AgoraConstants.callerTestingToken.isNotEmpty
              ? AgoraConstants.callerTestingToken
              : AgoraConstants.defaultToken)
          : (AgoraConstants.receiverTestingToken.isNotEmpty
              ? AgoraConstants.receiverTestingToken
              : AgoraConstants.defaultToken);

      final roleUid = widget.isCaller
          ? AgoraConstants.callerTestingUid
          : AgoraConstants.receiverTestingUid;

      final success = await _callingService.joinChannel(
        channelId: widget.call.channelId,
        token: roleToken.isNotEmpty ? roleToken : null,
        uid: roleUid,
        isVideo: true,
      );

      if (success) {
        if (mounted) {
          setState(() {
            _initLocalController();
            if (_callingService.remoteUid != null) {
              _remoteUid = _callingService.remoteUid;
              _initRemoteController(_remoteUid!);
            }
          });
        }
      } else if (mounted) {
        setState(() {
          _statusText = 'Connection failed';
        });
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          _handleCallTerminated('Connection failed');
        }
      }
    } catch (e) {
      debugPrint('[VideoCallingScreen] Error joining Agora video channel: $e');
      if (mounted) {
        setState(() {
          _statusText = 'Connection failed';
        });
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          _handleCallTerminated('Connection failed');
        }
      }
    }
  }

  /// Create local video controller for camera preview
  void _initLocalController() {
    if (_callingService.engine == null) return;
    if (_localController == null) {
      _localController = VideoViewController(
        rtcEngine: _callingService.engine!,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
        ),
      );
      if (mounted) setState(() {});
    }
  }

  /// Create remote video controller for remote peer stream
  void _initRemoteController(int uid) {
    if (_callingService.engine == null) return;
    if (_remoteController != null && _remoteControllerUid == uid) return;

    _remoteController?.dispose();
    _remoteControllerUid = uid;

    final effectiveChannel = AgoraConstants.defaultTestingChannel.isNotEmpty
        ? AgoraConstants.defaultTestingChannel
        : widget.call.channelId;

    _remoteController = VideoViewController.remote(
      rtcEngine: _callingService.engine!,
      canvas: VideoCanvas(
        uid: uid,
        renderMode: RenderModeType.renderModeHidden,
      ),
      connection: RtcConnection(channelId: effectiveChannel),
    );
    if (mounted) setState(() {});
  }

  /// Listen to Firestore call signaling state
  void _listenToCallState() {
    _callSubscription = _callSignalingService
        .listenToCall(widget.call.callId)
        .listen((updatedCall) {
      if (updatedCall == null || !mounted || _isEnding) return;

      if (updatedCall.status == CallStatus.connected && !_isConnected) {
        setState(() {
          _isConnected = true;
          _statusText = 'Connected';
        });
        _startTimer();
      } else if (updatedCall.status == CallStatus.rejected) {
        _handleCallTerminated('Call Declined');
      } else if (updatedCall.status == CallStatus.ended) {
        _handleCallTerminated('Call Ended');
      }
    });
  }

  void _startTimer() {
    if (_durationTimer != null && _durationTimer!.isActive) return;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _isConnected) {
        setState(() {
          _callDurationSeconds++;
        });
      }
    });
  }

  String _formatDuration(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  // --------------------------------------------------------------------------
  // Controls
  // --------------------------------------------------------------------------

  Future<void> _toggleMute() async {
    final newMute = !_isMuted;
    setState(() {
      _isMuted = newMute;
    });
    await _callingService.muteLocalAudio(newMute);
  }

  Future<void> _toggleCamera() async {
    final newCameraOff = !_isCameraOff;
    setState(() {
      _isCameraOff = newCameraOff;
    });
    await _callingService.enableLocalVideo(!newCameraOff);
  }

  Future<void> _switchCamera() async {
    await _callingService.switchCamera();
  }

  Future<void> _handleCallTerminated(String reason) async {
    if (_isEnding) return;
    _isEnding = true;

    _durationTimer?.cancel();
    _callSubscription?.cancel();

    if (mounted) {
      setState(() {
        _statusText = reason;
      });
    }

    await _cleanupAndLeave();

    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _endCall() async {
    if (_isEnding) return;
    _isEnding = true;

    _durationTimer?.cancel();
    _callSubscription?.cancel();

    setState(() {
      _statusText = 'Ending call...';
    });

    try {
      await _callSignalingService.endCall(
        callId: widget.call.callId,
        durationSeconds: _callDurationSeconds,
      );
    } catch (e) {
      debugPrint('[VideoCallingScreen] Error ending call in signaling: $e');
    }

    await _cleanupAndLeave();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _cleanupAndLeave() async {
    _callingService.clearVideoCallbacks();
    _localController?.dispose();
    _remoteController?.dispose();
    _localController = null;
    _remoteController = null;
    _remoteControllerUid = null;
    await _callingService.leaveChannel();
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    _callingService.clearVideoCallbacks();
    _localController?.dispose();
    _remoteController?.dispose();
    super.dispose();
  }

  // --------------------------------------------------------------------------
  // UI Building
  // --------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Remote Video (Full Screen) or Placeholder
            Positioned.fill(
              child: _buildRemoteVideoOrPlaceholder(),
            ),

            // 2. Floating Local Camera Preview (Top Right)
            Positioned(
              top: 50,
              right: 16,
              width: 110,
              height: 160,
              child: _buildFloatingLocalPreview(),
            ),

            // 3. Top Header with User Info & Status
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopHeader(),
            ),

            // 4. Bottom Controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),
          ],
        ),
      ),
    );
  }

  /// Full-screen remote video stream or polished placeholder if not yet available
  Widget _buildRemoteVideoOrPlaceholder() {
    if (_remoteUid != null &&
        _isRemoteVideoActive &&
        _remoteController != null) {
      return AgoraVideoView(
        controller: _remoteController!,
      );
    }

    // Placeholder view while waiting for remote video
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1E293B),
            Color(0xFF0F172A),
            Colors.black,
          ],
        ),
      ),
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar with pulse effect
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.4),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: _remotePartyAvatar.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _remotePartyAvatar,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
              ),
              const SizedBox(height: 24),
              Text(
                _remotePartyName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isConnected) ...[
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.accentColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    _isConnected ? 'Waiting for remote video...' : _statusText,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Floating local camera preview (Picture-in-Picture)
  Widget _buildFloatingLocalPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: _isCameraOff
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28),
                    SizedBox(height: 4),
                    Text(
                      'Camera Off',
                      style: TextStyle(color: Colors.white54, fontSize: 10),
                    ),
                  ],
                ),
              )
            : (_localController != null
                ? AgoraVideoView(controller: _localController!)
                : const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  )),
      ),
    );
  }

  /// Top header showing remote peer name and connection badge
  Widget _buildTopHeader() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // User & Status card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isConnected
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _remotePartyName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _isConnected
                            ? _formatDuration(_callDurationSeconds)
                            : _statusText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bottom in-call media control bar
  Widget _buildBottomControls() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.85),
              Colors.black.withValues(alpha: 0.0),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 1. Microphone Mute Toggle
            CallButton(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              backgroundColor: _isMuted ? Colors.white : Colors.white24,
              iconColor: _isMuted ? Colors.black : Colors.white,
              onPressed: _toggleMute,
            ),

            // 2. Camera ON/OFF Toggle
            CallButton(
              icon: _isCameraOff
                  ? Icons.videocam_off_rounded
                  : Icons.videocam_rounded,
              backgroundColor: _isCameraOff ? Colors.white : Colors.white24,
              iconColor: _isCameraOff ? Colors.black : Colors.white,
              onPressed: _toggleCamera,
            ),

            // 3. Switch Camera (Front/Rear)
            CallButton(
              icon: Icons.flip_camera_ios_rounded,
              backgroundColor: Colors.white24,
              iconColor: Colors.white,
              onPressed: _switchCamera,
            ),

            // 4. End Call
            CallButton(
              icon: Icons.call_end_rounded,
              backgroundColor: AppTheme.errorColor,
              iconColor: Colors.white,
              size: 64,
              onPressed: _endCall,
            ),
          ],
        ),
      ),
    );
  }
}
