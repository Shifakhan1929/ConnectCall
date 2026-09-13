import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/calling_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_tile.dart';
import '../contacts/contacts_screen.dart';
import '../history/call_history_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _onNavigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeFeedView(onNavigateToTab: _onNavigateToTab),
      const ContactsScreen(),
      const CallHistoryScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts_rounded),
            label: 'Contacts',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_outlined),
            selectedIcon: Icon(Icons.call_rounded),
            label: 'Calls',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomeFeedView extends StatefulWidget {
  final ValueChanged<int> onNavigateToTab;

  const HomeFeedView({super.key, required this.onNavigateToTab});

  @override
  State<HomeFeedView> createState() => _HomeFeedViewState();
}

class _HomeFeedViewState extends State<HomeFeedView> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  final CallingService _callingService = CallingService();

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  UserModel? _currentUserProfile;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    final user = _authService.currentUser ?? await _authService.checkAuthState();
    if (mounted) {
      setState(() {
        _currentUserProfile = user;
      });
    }
  }

  void _showCallingNotice(String type) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$type calling will be enabled in the calling module.'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final difference = now.difference(dt);

    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return mins <= 1 ? 'Just now' : '${mins}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dt.day}/${dt.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = _authService.currentFirebaseUser?.uid;

    final userName = _currentUserProfile?.name.isNotEmpty == true
        ? _currentUserProfile!.name
        : (_authService.currentFirebaseUser?.displayName ?? 'User');

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Current User Profile Header
              InkWell(
                onTap: () => widget.onNavigateToTab(3), // Jump to Profile
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // User Avatar with Online status
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                AppTheme.primaryColor.withValues(alpha: 0.15),
                            backgroundImage: _currentUserProfile?.avatarUrl != null
                                ? NetworkImage(_currentUserProfile!.avatarUrl!)
                                : null,
                            child: _currentUserProfile?.avatarUrl == null
                                ? Text(
                                    userName.isNotEmpty
                                        ? userName[0].toUpperCase()
                                        : '?',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryColor,
                                      fontSize: 18,
                                    ),
                                  )
                                : null,
                          ),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppTheme.accentColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark
                                    ? AppTheme.darkSurface
                                    : Colors.white,
                                width: 2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 14),

                      // Greeting & Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, welcome back 👋',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              userName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      // Profile status pill
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.circle,
                                size: 6, color: AppTheme.accentColor),
                            SizedBox(width: 6),
                            Text(
                              'Online',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // 2. Search Users Field
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search users by name or email...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark
                      ? AppTheme.darkSurface
                      : Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (query) {
                  setState(() {
                    _searchQuery = query.trim().toLowerCase();
                  });
                },
              ),
              const SizedBox(height: 20),

              // 3. Contacts / Users Section
              StreamBuilder<List<UserModel>>(
                stream: _userService.getUsersStream(excludeUserId: currentUserId),
                builder: (context, snapshot) {
                  final allUsers = snapshot.data ?? [];
                  final filteredUsers = _searchQuery.isEmpty
                      ? allUsers
                      : allUsers.where((u) {
                          return u.name.toLowerCase().contains(_searchQuery) ||
                              u.email.toLowerCase().contains(_searchQuery);
                        }).toList();

                  // Online contacts carousel (shown when not actively searching)
                  final onlineUsers =
                      allUsers.where((u) => u.isOnline).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active users quick row (when not searching and online users exist)
                      if (_searchQuery.isEmpty && onlineUsers.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Active Now',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            Text(
                              '${onlineUsers.length} Online',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.accentColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 84,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: onlineUsers.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final onlineUser = onlineUsers[index];
                              return InkWell(
                                onTap: () => _showCallingNotice('Video'),
                                borderRadius: BorderRadius.circular(12),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.bottomRight,
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: AppTheme.primaryColor
                                              .withValues(alpha: 0.15),
                                          child: Text(
                                            onlineUser.name.isNotEmpty
                                                ? onlineUser.name[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          width: 12,
                                          height: 12,
                                          decoration: BoxDecoration(
                                            color: AppTheme.accentColor,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isDark
                                                  ? AppTheme.darkBackground
                                                  : Colors.white,
                                              width: 2,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 60,
                                      child: Text(
                                        onlineUser.name.split(' ').first,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Contacts Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _searchQuery.isEmpty ? 'Contacts' : 'Search Results',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_searchQuery.isEmpty)
                            TextButton(
                              onPressed: () => widget.onNavigateToTab(1),
                              child: const Text('See all'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Contacts list preview (up to 4 items on home)
                      if (filteredUsers.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              _searchQuery.isEmpty
                                  ? 'No registered contacts yet.'
                                  : 'No contacts matching "$_searchQuery"',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        )
                      else
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: filteredUsers.length > 4 && _searchQuery.isEmpty
                                ? 4
                                : filteredUsers.length,
                            separatorBuilder: (context, index) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final user = filteredUsers[index];
                              return UserTile(
                                user: user,
                                onAudioCall: () => _showCallingNotice('Audio'),
                                onVideoCall: () => _showCallingNotice('Video'),
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),

              // 4. Recent Calls Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Calls',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () => widget.onNavigateToTab(2),
                    child: const Text('See all'),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              StreamBuilder<List<CallModel>>(
                stream: _callingService.getCallHistoryStream(userId: currentUserId),
                builder: (context, snapshot) {
                  final history = snapshot.data ?? [];

                  if (history.isEmpty) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 24),
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.phone_in_talk_outlined,
                            size: 40,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'No recent calls yet',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Start audio or video calls with your contacts above.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: history.length > 3 ? 3 : history.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final call = history[index];
                        final isOutgoing = call.callerId == currentUserId;
                        final isMissed = call.status == CallStatus.missed;
                        final isVideo = call.type == CallType.video;
                        final otherParty =
                            isOutgoing ? call.receiverName : call.callerName;

                        return ListTile(
                          leading: CircleAvatar(
                            radius: 20,
                            backgroundColor: isMissed
                                ? AppTheme.errorColor.withValues(alpha: 0.12)
                                : AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: Icon(
                              isVideo
                                  ? Icons.videocam_rounded
                                  : Icons.call_rounded,
                              size: 20,
                              color: isMissed
                                  ? AppTheme.errorColor
                                  : AppTheme.primaryColor,
                            ),
                          ),
                          title: Text(
                            otherParty,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isMissed ? AppTheme.errorColor : null,
                            ),
                          ),
                          subtitle: Text(
                            '${call.status.name.toUpperCase()} • ${_formatTimestamp(call.timestamp)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: Icon(
                              isVideo
                                  ? Icons.videocam_outlined
                                  : Icons.call_outlined,
                              size: 20,
                              color: AppTheme.primaryColor,
                            ),
                            onPressed: () => _showCallingNotice(
                              isVideo ? 'Video' : 'Audio',
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
