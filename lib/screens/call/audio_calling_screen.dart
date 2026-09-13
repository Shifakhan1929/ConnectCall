import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/constants/agora_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../services/call_signaling_service.dart';
import '../../services/calling_service.dart';
import '../../widgets/call_button.dart';

class AudioCallingScreen extends StatefulWidget {
  final CallModel call;
  final bool isCaller;

  const AudioCallingScreen({
    super.key,
    required this.call,
    required this.isCaller,
  });

  @override
  State<AudioCallingScreen> createState() => _AudioCallingScreenState();
}

class _AudioCallingScreenState extends State<AudioCallingScreen> {
  final CallingService _callingService = CallingService();
  final CallSignalingService _callSignalingService = CallSignalingService();

  StreamSubscription<CallModel?>? _callSubscription;
  Timer? _durationTimer;

  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isConnected = false;
  int _callDurationSeconds = 0;
  String _statusText = 'Connecting...';
  bool _isEnding = false;

  @override
  void initState() {
    super.initState();
    _statusText = widget.isCaller ? 'Calling...' : 'Connecting...';
    _initializeAndJoin();
    _listenToCallState();
  }

  Future<void> _initializeAndJoin() async {
    try {
      // Determine testing token and UID based on caller vs receiver
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

      // Join Agora audio channel (audio only, isVideo: false)
      final success = await _callingService.joinChannel(
        channelId: widget.call.channelId,
        token: roleToken.isNotEmpty ? roleToken : null,
        uid: roleUid,
        isVideo: false,
      );

      if (!success && mounted) {
        setState(() {
          _statusText = 'Connection failed';
        });
        await Future.delayed(const Duration(milliseconds: 2000));
        if (mounted) {
          _handleCallTerminated('Connection failed');
        }
      }
    } catch (e) {
      debugPrint('Error joining Agora audio channel: $e');
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
    _durationTimer?.cancel();
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

    await _callingService.leaveChannel();

    await Future.delayed(const Duration(milliseconds: 1200));
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
      await _callingService.leaveChannel();
      await _callSignalingService.endCall(
        callId: widget.call.callId,
        durationSeconds: _callDurationSeconds,
      );
    } catch (e) {
      debugPrint('Error ending call: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    final nextMuteState = !_isMuted;
    _callingService.muteLocalAudio(nextMuteState);
    setState(() {
      _isMuted = nextMuteState;
    });
  }

  void _toggleSpeaker() {
    final nextSpeakerState = !_isSpeakerOn;
    _callingService.toggleSpeakerphone(nextSpeakerState);
    setState(() {
      _isSpeakerOn = nextSpeakerState;
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = widget.isCaller
        ? widget.call.receiverName
        : widget.call.callerName;
    final avatarUrl = widget.isCaller
        ? widget.call.receiverAvatar
        : widget.call.callerAvatar;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _endCall();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 20),

              // Audio Call Header Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mic, color: Colors.white70, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'HD Voice Call',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // Caller / Receiver Avatar with active pulsing ring
              Stack(
                alignment: Alignment.center,
                children: [
                  if (_isConnected)
                    Container(
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.accentColor.withValues(alpha: 0.15),
                      ),
                    ),
                  CircleAvatar(
                    radius: 56,
                    backgroundColor:
                        AppTheme.primaryColor.withValues(alpha: 0.25),
                    backgroundImage:
                        hasAvatar ? NetworkImage(avatarUrl) : null,
                    child: !hasAvatar
                        ? Text(
                            displayName.isNotEmpty
                                ? displayName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Name
              Text(
                displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Call Status / Live Duration
              Text(
                _isConnected ? _formatDuration(_callDurationSeconds) : _statusText,
                style: TextStyle(
                  color: _isConnected
                      ? AppTheme.accentColor
                      : Colors.white.withValues(alpha: 0.7),
                  fontSize: _isConnected ? 18 : 16,
                  fontWeight: _isConnected ? FontWeight.bold : FontWeight.normal,
                  letterSpacing: _isConnected ? 1.0 : 0.0,
                ),
              ),

              const Spacer(flex: 3),

              // Audio In-Call Controls
              Padding(
                padding: const EdgeInsets.only(bottom: 40.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mute / Unmute Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallButton(
                          icon: _isMuted ? Icons.mic_off : Icons.mic,
                          backgroundColor:
                              _isMuted ? Colors.white : Colors.white24,
                          iconColor: _isMuted ? Colors.black : Colors.white,
                          size: 58,
                          onPressed: _toggleMute,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isMuted ? 'Unmute' : 'Mute',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // Speakerphone Toggle Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallButton(
                          icon: _isSpeakerOn
                              ? Icons.volume_up
                              : Icons.volume_down,
                          backgroundColor:
                              _isSpeakerOn ? Colors.white : Colors.white24,
                          iconColor:
                              _isSpeakerOn ? Colors.black : Colors.white,
                          size: 58,
                          onPressed: _toggleSpeaker,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isSpeakerOn ? 'Speaker On' : 'Speaker',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    // End Call Button
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallButton(
                          icon: Icons.call_end,
                          backgroundColor: AppTheme.errorColor,
                          iconColor: Colors.white,
                          size: 58,
                          onPressed: _endCall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'End',
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
      ),
    );
  }
}
