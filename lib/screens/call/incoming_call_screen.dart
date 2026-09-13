import 'package:flutter/material.dart';
import '../../models/call_model.dart';
import '../../widgets/call_button.dart';

class IncomingCallScreen extends StatelessWidget {
  final CallModel? call;

  const IncomingCallScreen({super.key, this.call});

  @override
  Widget build(BuildContext context) {
    final isVideo = call?.type == CallType.video;

    return Scaffold(
      backgroundColor: Colors.black87,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.indigo.shade300,
              child: const Icon(Icons.person, size: 64, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              call?.callerName ?? 'Incoming Caller',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isVideo ? 'Incoming Video Call...' : 'Incoming Audio Call...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 16,
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: 48.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Reject button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CallButton(
                        icon: Icons.call_end,
                        backgroundColor: Colors.red,
                        iconColor: Colors.white,
                        onPressed: () {
                          // TODO: callingService.rejectCall()
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text('Decline', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  // Accept button
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CallButton(
                        icon: Icons.call,
                        backgroundColor: Colors.green,
                        iconColor: Colors.white,
                        onPressed: () {
                          // TODO: callingService.acceptCall()
                        },
                      ),
                      const SizedBox(height: 8),
                      const Text('Accept', style: TextStyle(color: Colors.white70)),
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
}
