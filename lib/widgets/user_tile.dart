import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';
import '../models/user_model.dart';

class UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onAudioCall;
  final VoidCallback? onVideoCall;
  final VoidCallback? onTap;

  const UserTile({
    super.key,
    required this.user,
    this.onAudioCall,
    this.onVideoCall,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      leading: Stack(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
            backgroundImage: hasAvatar ? NetworkImage(user.avatarUrl!) : null,
            child: !hasAvatar
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryColor,
                    ),
                  )
                : null,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: user.isOnline ? AppTheme.accentColor : Colors.grey.shade400,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Text(
        user.name.isNotEmpty ? user.name : 'Unknown User',
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
        ),
      ),
      subtitle: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: user.isOnline ? AppTheme.accentColor : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            user.isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: user.isOnline
                  ? AppTheme.accentColor
                  : (isDark ? Colors.white38 : Colors.black45),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              user.email,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.call_outlined, color: AppTheme.primaryColor),
            onPressed: onAudioCall,
            tooltip: 'Audio Call',
            splashRadius: 22,
          ),
          IconButton(
            icon: const Icon(Icons.videocam_outlined, color: AppTheme.primaryColor),
            onPressed: onVideoCall,
            tooltip: 'Video Call',
            splashRadius: 22,
          ),
        ],
      ),
    );
  }
}
