import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/network_helper.dart';
import '../../core/utils/permission_helper.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/call_history_service.dart';
import '../../services/call_signaling_service.dart';
import '../call/audio_calling_screen.dart';
import '../call/video_calling_screen.dart';

/// CallHistoryScreen presents past audio and video call records.
///
/// Features:
/// - Real-time stream from CallHistoryService filtered by current user
/// - Search by contact name
/// - Filter chips: All, Audio, Video
/// - Clear incoming, outgoing, missed, and rejected badges
/// - Call duration and formatted timestamp indicators
/// - Direct callback button for audio and video
class CallHistoryScreen extends StatefulWidget {
  const CallHistoryScreen({super.key});

  @override
  State<CallHistoryScreen> createState() => _CallHistoryScreenState();
}

class _CallHistoryScreenState extends State<CallHistoryScreen> {
  final CallHistoryService _callHistoryService = CallHistoryService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  CallType? _selectedTypeFilter;
  bool _isStartingCall = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24 && dt.day == now.day) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Today, $hour:$minute';
    } else if (difference.inDays < 2) {
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return 'Yesterday, $hour:$minute';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0s';
    final mins = seconds ~/ 60;
    final remainingSecs = seconds % 60;
    if (mins == 0) {
      return '${remainingSecs}s';
    }
    return '${mins}m ${remainingSecs}s';
  }

  Future<void> _startCall(CallModel call, {required bool isVideo}) async {
    if (_isStartingCall) return;
    setState(() => _isStartingCall = true);

    try {
      final hasInternet = await NetworkHelper.hasInternetConnection();
      if (!hasInternet) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet connection. Please check your network and try again.'),
              backgroundColor: AppTheme.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      final permResult =
          await PermissionHelper.checkAndRequestCallPermissions(isVideo: isVideo);
      if (!permResult.isGranted) {
        if (mounted) {
          PermissionHelper.handlePermissionResult(context, permResult);
        }
        return;
      }

      final currentUserId = _authService.currentFirebaseUser?.uid;
      if (currentUserId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to start a call.')),
          );
        }
        return;
      }

      final targetId = call.getOtherPartyId(currentUserId);
      final targetName = call.getOtherPartyName(currentUserId);
      final targetAvatar = call.getOtherPartyAvatar(currentUserId);

      final receiver = UserModel(
        id: targetId,
        name: targetName,
        email: '',
        avatarUrl: targetAvatar,
      );

      final caller = _authService.currentUser;
      if (caller == null) return;

      final callDoc = await CallSignalingService().initiateCall(
        caller: caller,
        receiver: receiver,
        type: isVideo ? CallType.video : CallType.audio,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => isVideo
              ? VideoCallingScreen(call: callDoc, isCaller: true)
              : AudioCallingScreen(call: callDoc, isCaller: true),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start call: $e'),
          backgroundColor: AppTheme.errorColor,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isStartingCall = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = _authService.currentFirebaseUser?.uid;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Call History'),
      ),
      body: Column(
        children: [
          // 1. Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search calls by contact name...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // 2. Filter Chips (All, Audio, Video)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Calls'),
                  selected: _selectedTypeFilter == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedTypeFilter = null;
                      });
                    }
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.call_rounded, size: 16),
                  label: const Text('Audio'),
                  selected: _selectedTypeFilter == CallType.audio,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTypeFilter = selected ? CallType.audio : null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  avatar: const Icon(Icons.videocam_rounded, size: 16),
                  label: const Text('Video'),
                  selected: _selectedTypeFilter == CallType.video,
                  onSelected: (selected) {
                    setState(() {
                      _selectedTypeFilter = selected ? CallType.video : null;
                    });
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Real-time Stream List
          Expanded(
            child: StreamBuilder<List<CallModel>>(
              stream: _callHistoryService.getCallHistoryStream(
                userId: currentUserId,
                typeFilter: _selectedTypeFilter,
                searchQuery: _searchQuery,
              ),
              builder: (context, snapshot) {
                // Loading State
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Loading call history...',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                final history = snapshot.data ?? [];

                // Empty State
                if (history.isEmpty) {
                  final isFiltered = _searchQuery.isNotEmpty || _selectedTypeFilter != null;

                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFiltered
                                  ? Icons.search_off_rounded
                                  : Icons.phone_missed_rounded,
                              size: 52,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            isFiltered ? 'No Matching Calls' : 'No Recent Calls',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isFiltered
                                ? 'No call records matched your search or type filter.'
                                : 'Your incoming, outgoing, and missed call logs will appear here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          if (isFiltered) ...[
                            const SizedBox(height: 16),
                            TextButton.icon(
                              icon: const Icon(Icons.refresh_rounded, size: 18),
                              label: const Text('Reset filters'),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                  _selectedTypeFilter = null;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                // Call History List
                return ListView.separated(
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final call = history[index];
                    final isOutgoing = currentUserId != null && call.isOutgoing(currentUserId);
                    final isMissed = call.status == CallStatus.missed;
                    final isRejected = call.status == CallStatus.rejected;
                    final isVideo = call.type == CallType.video;

                    final otherPartyName = currentUserId != null
                        ? call.getOtherPartyName(currentUserId)
                        : (isOutgoing ? call.receiverName : call.callerName);

                    final otherPartyAvatar = currentUserId != null
                        ? call.getOtherPartyAvatar(currentUserId)
                        : (isOutgoing ? call.receiverAvatar : call.callerAvatar);

                    // Direction icon & status label
                    IconData directionIcon;
                    Color directionColor;
                    String statusLabel;

                    if (isMissed) {
                      directionIcon = Icons.call_missed_rounded;
                      directionColor = AppTheme.errorColor;
                      statusLabel = 'MISSED';
                    } else if (isRejected) {
                      directionIcon = Icons.phone_disabled_rounded;
                      directionColor = AppTheme.errorColor;
                      statusLabel = 'DECLINED';
                    } else if (isOutgoing) {
                      directionIcon = Icons.call_made_rounded;
                      directionColor = const Color(0xFF10B981);
                      statusLabel = 'OUTGOING';
                    } else {
                      directionIcon = Icons.call_received_rounded;
                      directionColor = AppTheme.primaryColor;
                      statusLabel = 'INCOMING';
                    }

                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: isMissed || isRejected
                                ? AppTheme.errorColor.withValues(alpha: 0.12)
                                : AppTheme.primaryColor.withValues(alpha: 0.12),
                            backgroundImage: (otherPartyAvatar != null &&
                                    otherPartyAvatar.isNotEmpty)
                                ? NetworkImage(otherPartyAvatar)
                                : null,
                            child: (otherPartyAvatar == null ||
                                    otherPartyAvatar.isEmpty)
                                ? Icon(
                                    isVideo
                                        ? Icons.videocam_rounded
                                        : Icons.call_rounded,
                                    color: isMissed || isRejected
                                        ? AppTheme.errorColor
                                        : AppTheme.primaryColor,
                                    size: 22,
                                  )
                                : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppTheme.darkBackground
                                    : Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isVideo
                                    ? Icons.videocam_rounded
                                    : Icons.call_rounded,
                                size: 12,
                                color: isVideo
                                    ? const Color(0xFF6366F1)
                                    : AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      title: Text(
                        otherPartyName.isNotEmpty ? otherPartyName : 'Unknown Contact',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: isMissed || isRejected
                              ? AppTheme.errorColor
                              : null,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 3.0),
                        child: Row(
                          children: [
                            Icon(
                              directionIcon,
                              size: 13,
                              color: directionColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: directionColor,
                              ),
                            ),
                            Text(
                              ' • ${_formatTimestamp(call.timestamp)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            if (call.durationSeconds > 0) ...[
                              Text(
                                ' • ${_formatDuration(call.durationSeconds)}',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isVideo
                              ? Icons.videocam_outlined
                              : Icons.call_outlined,
                          color: AppTheme.primaryColor,
                          size: 22,
                        ),
                        tooltip: isVideo ? 'Video Call' : 'Audio Call',
                        onPressed: _isStartingCall ? null : () => _startCall(call, isVideo: isVideo),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
