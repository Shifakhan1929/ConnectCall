import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/permission_helper.dart';
import '../../models/call_model.dart';
import '../../services/call_signaling_service.dart';
import '../../widgets/call_button.dart';
import 'audio_calling_screen.dart';
import 'video_calling_screen.dart';

class IncomingCallScreen extends StatefulWidget {
  final CallModel? call;

  const IncomingCallScreen({super.key, this.call});

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  final CallSignalingService _callSignalingService = CallSignalingService();
  StreamSubscription<CallModel?>? _callSubscription;
  CallModel? _activeCall;
  bool _isResponding = false;

  @override
  void initState() {
    super.initState();
    _activeCall = widget.call;
    if (_activeCall != null) {
      _listenToCallState();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_activeCall == null) {
      final routeCall = ModalRoute.of(context)?.settings.arguments as CallModel?;
      if (routeCall != null) {
        setState(() {
          _activeCall = routeCall;
        });
        _listenToCallState();
      }
    }
  }

  void _listenToCallState() {
    final callId = _activeCall?.callId;
    if (callId == null) return;

    _callSubscription?.cancel();
    _callSubscription = _callSignalingService
        .listenToCall(callId)
        .listen((updatedCall) {
      // If the caller cancelled or ended the call while ringing
      if (updatedCall == null ||
          updatedCall.status == CallStatus.ended ||
          updatedCall.status == CallStatus.rejected) {
        if (mounted && !_isResponding) {
          Navigator.pop(context);
        }
      }
    });
  }

  Future<void> _handleDecline() async {
    final call = _activeCall;
    if (call == null || _isResponding) return;
    _isResponding = true;

    _callSubscription?.cancel();

    try {
      await _callSignalingService.rejectCall(call.callId);
    } catch (e) {
      debugPrint('Error rejecting call: $e');
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleAccept() async {
    final call = _activeCall;
    if (call == null || _isResponding) return;
    _isResponding = true;

    final isVideo = call.type == CallType.video;
    // 1. Verify required permissions
    final permResult =
        await PermissionHelper.checkAndRequestCallPermissions(isVideo: isVideo);
    if (!permResult.isGranted) {
      _isResponding = false;
      if (mounted) {
        PermissionHelper.handlePermissionResult(context, permResult);
      }
      return;
    }

    _callSubscription?.cancel();

    // 2. Mark call as connected in Firestore
    try {
      await _callSignalingService.acceptCall(call.callId);
    } catch (e) {
      debugPrint('Error accepting call in Firestore: $e');
    }

    // 3. Navigate to VideoCallingScreen or AudioCallingScreen
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => isVideo
              ? VideoCallingScreen(
                  call: call,
                  isCaller: false,
                )
              : AudioCallingScreen(
                  call: call,
                  isCaller: false,
                ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _callSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final call = _activeCall;
    if (call == null) {
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final callerName = call.callerName;
    final avatarUrl = call.callerAvatar;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _handleDecline();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),

              // Caller Avatar
              CircleAvatar(
                radius: 60,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.25),
                backgroundImage:
                    hasAvatar ? NetworkImage(avatarUrl) : null,
                child: !hasAvatar
                    ? Text(
                        callerName.isNotEmpty
                            ? callerName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 24),

              // Caller Name
              Text(
                callerName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                'Incoming Audio Call...',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),

              const Spacer(flex: 3),

              // Decline & Accept Buttons
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Decline
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallButton(
                          icon: Icons.call_end,
                          backgroundColor: AppTheme.errorColor,
                          iconColor: Colors.white,
                          size: 64,
                          onPressed: _handleDecline,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Decline',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),

                    // Accept
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CallButton(
                          icon: Icons.call,
                          backgroundColor: AppTheme.accentColor,
                          iconColor: Colors.white,
                          size: 64,
                          onPressed: _handleAccept,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Accept',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
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
