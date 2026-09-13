import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/network_helper.dart';
import '../../core/utils/permission_helper.dart';
import '../../models/call_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/call_signaling_service.dart';
import '../../services/user_service.dart';
import '../../widgets/user_tile.dart';
import '../call/audio_calling_screen.dart';
import '../call/video_calling_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final UserService _userService = UserService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isStartingCall = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startAudioCall(UserModel receiver) async {
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

      final permResult = await PermissionHelper.checkAndRequestCallPermissions(isVideo: false);
      if (!permResult.isGranted) {
        if (mounted) {
          PermissionHelper.handlePermissionResult(context, permResult);
        }
        return;
      }

      final currentUser = _authService.currentUser ?? await _authService.checkAuthState();
      if (currentUser == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User session not found. Please log in again.'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }

      final call = await CallSignalingService().initiateCall(
        caller: currentUser,
        receiver: receiver,
        type: CallType.audio,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AudioCallingScreen(
            call: call,
            isCaller: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error starting audio call: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place call: $e'),
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

  Future<void> _startVideoCall(UserModel receiver) async {
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

      final permResult = await PermissionHelper.checkAndRequestCallPermissions(isVideo: true);
      if (!permResult.isGranted) {
        if (mounted) {
          PermissionHelper.handlePermissionResult(context, permResult);
        }
        return;
      }

      final caller = _authService.currentUser;
      if (caller == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please log in to start a call.')),
          );
        }
        return;
      }

      final callDoc = await CallSignalingService().initiateCall(
        caller: caller,
        receiver: receiver,
        type: CallType.video,
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VideoCallingScreen(
            call: callDoc,
            isCaller: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error starting video call: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to place video call: $e'),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
      ),
      body: Column(
        children: [
          // Search Input
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search contacts by name or email...',
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
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (query) {
                setState(() {
                  _searchQuery = query.trim().toLowerCase();
                });
              },
            ),
          ),

          // Contacts Stream List
          Expanded(
            child: StreamBuilder<List<UserModel>>(
              stream: _userService.getUsersStream(excludeUserId: currentUserId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 56,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Failed to load contacts',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: () => setState(() {}),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final users = snapshot.data ?? [];
                final filteredUsers = _searchQuery.isEmpty
                    ? users
                    : users.where((u) {
                        return u.name.toLowerCase().contains(_searchQuery) ||
                            u.email.toLowerCase().contains(_searchQuery);
                      }).toList();

                if (filteredUsers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _searchQuery.isEmpty
                                ? Icons.people_outline
                                : Icons.search_off_rounded,
                            size: 64,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No contacts yet'
                                : 'No contacts matching "$_searchQuery"',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isEmpty
                                ? 'Other users who register will appear here.'
                                : 'Try searching with a different name or email.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 8.0),
                      child: Text(
                        '${filteredUsers.length} Contact${filteredUsers.length == 1 ? '' : 's'}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: filteredUsers.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final user = filteredUsers[index];
                          return UserTile(
                            user: user,
                            onAudioCall: _isStartingCall ? null : () => _startAudioCall(user),
                            onVideoCall: _isStartingCall ? null : () => _startVideoCall(user),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
