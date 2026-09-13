import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../widgets/call_button.dart';

class CallScreen extends StatefulWidget {
  final CallModel? call;

  const CallScreen({super.key, this.call});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  bool _isMuted = false;
  bool _isCameraOff = false;

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.call?.type == CallType.video;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Caller/Receiver Avatar or Video placeholder
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.indigo.shade300,
              child: const Icon(Icons.person, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              widget.call?.receiverName ?? 'Contact Name',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Video Call' : 'Audio Call',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const Spacer(),
            // Call control buttons
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CallButton(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    backgroundColor: _isMuted ? Colors.white : Colors.white24,
                    iconColor: _isMuted ? Colors.black : Colors.white,
                    onPressed: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                      // TODO: callingService.toggleMute()
                    },
                  ),
                  if (isVideo) ...[
                    CallButton(
                      icon: _isCameraOff ? Icons.videocam_off : Icons.videocam,
                      backgroundColor: _isCameraOff ? Colors.white : Colors.white24,
                      iconColor: _isCameraOff ? Colors.black : Colors.white,
                      onPressed: () {
                        setState(() {
                          _isCameraOff = !_isCameraOff;
                        });
                        // TODO: callingService.toggleCamera()
                      },
                    ),
                    CallButton(
                      icon: Icons.switch_camera,
                      backgroundColor: Colors.white24,
                      iconColor: Colors.white,
                      onPressed: () {
                        // TODO: callingService.switchCamera()
                      },
                    ),
                  ],
                  CallButton(
                    icon: Icons.call_end,
                    backgroundColor: Colors.red,
                    iconColor: Colors.white,
                    onPressed: () {
                      // TODO: callingService.endCall()
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
