import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../services/auth_service.dart';
import '../../services/calling_service.dart';

class CallHistoryScreen extends StatelessWidget {
  const CallHistoryScreen({super.key});

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins <= 1 ? 'Just now' : '${mins}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  void _showCallingNotice(BuildContext context, String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type calling will be enabled in the calling module.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthService().currentFirebaseUser?.uid;
    final callingService = CallingService();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
      ),
      body: StreamBuilder<List<CallModel>>(
        stream: callingService.getCallHistoryStream(userId: currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final history = snapshot.data ?? [];

          if (history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.phone_missed_rounded,
                        size: 56,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Recent Calls',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your incoming, outgoing, and missed call logs will be recorded here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: history.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final call = history[index];
              final isOutgoing = call.callerId == currentUserId;
              final isMissed = call.status == CallStatus.missed;
              final isVideo = call.type == CallType.video;
              final otherPartyName =
                  isOutgoing ? call.receiverName : call.callerName;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: isMissed
                      ? AppTheme.errorColor.withValues(alpha: 0.12)
                      : AppTheme.primaryColor.withValues(alpha: 0.12),
                  child: Icon(
                    isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                    color: isMissed ? AppTheme.errorColor : AppTheme.primaryColor,
                  ),
                ),
                title: Text(
                  otherPartyName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isMissed ? AppTheme.errorColor : null,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      isOutgoing
                          ? Icons.call_made_rounded
                          : (isMissed
                              ? Icons.call_missed_rounded
                              : Icons.call_received_rounded),
                      size: 14,
                      color: isMissed ? AppTheme.errorColor : Colors.grey,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${call.status.name.toUpperCase()} • ${_formatTimestamp(call.timestamp)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isMissed ? AppTheme.errorColor : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: Icon(
                    isVideo ? Icons.videocam_outlined : Icons.call_outlined,
                    color: AppTheme.primaryColor,
                  ),
                  onPressed: () => _showCallingNotice(
                    context,
                    isVideo ? 'Video' : 'Audio',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
