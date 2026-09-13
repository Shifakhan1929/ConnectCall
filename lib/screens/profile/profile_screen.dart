import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/common_button.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final UserService _userService = UserService();
  bool _isLoggingOut = false;

  void _showEditProfileModal(UserModel user) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController(text: user.name);
    final avatarController = TextEditingController(text: user.avatarUrl ?? '');
    bool isSaving = false;

    // Preset avatar URLs for quick selection
    final presetAvatars = [
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
      'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150',
      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
      'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=150',
      'https://images.unsplash.com/photo-1628157582853-a796fa650a6a?w=150',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 24,
              left: 24,
              right: 24,
            ),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Edit Profile',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),

                    // Quick Preset Avatars
                    const Text(
                      'Choose Avatar',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: presetAvatars.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            final isDefaultSelected =
                                avatarController.text.trim().isEmpty;
                            return GestureDetector(
                              onTap: () {
                                setModalState(() {
                                  avatarController.clear();
                                });
                              },
                              child: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.primaryColor
                                      .withValues(alpha: 0.15),
                                  border: Border.all(
                                    color: isDefaultSelected
                                        ? AppTheme.primaryColor
                                        : Colors.transparent,
                                    width: 2.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_outline,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            );
                          }

                          final url = presetAvatars[index - 1];
                          final isSelected = avatarController.text.trim() == url;

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                avatarController.text = url;
                              });
                            },
                            child: Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? AppTheme.primaryColor
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.network(
                                  url,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(Icons.person),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Name Field
                    TextFormField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Display Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Please enter your name';
                        }
                        if (val.trim().length < 2) {
                          return 'Name must be at least 2 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Custom Avatar URL Field
                    TextFormField(
                      controller: avatarController,
                      decoration: InputDecoration(
                        labelText: 'Custom Avatar URL (Optional)',
                        hintText: 'https://example.com/avatar.jpg',
                        prefixIcon: const Icon(Icons.link_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    CommonButton(
                      label: 'Save Changes',
                      icon: Icons.check_circle_outline,
                      isLoading: isSaving,
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;

                              setModalState(() {
                                isSaving = true;
                              });

                              try {
                                await _userService.updateProfile(
                                  userId: user.id,
                                  name: nameController.text.trim(),
                                  avatarUrl: avatarController.text.trim().isNotEmpty
                                      ? avatarController.text.trim()
                                      : null,
                                );

                                // Sync display name in Firebase Auth
                                await _authService.currentFirebaseUser
                                    ?.updateDisplayName(
                                        nameController.text.trim());

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Profile updated successfully!'),
                                      backgroundColor: AppTheme.accentColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                setModalState(() {
                                  isSaving = false;
                                });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to update profile: $e'),
                                      backgroundColor: AppTheme.errorColor,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out of ConnectCall?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (shouldLogout != true) return;

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _authService.logout();
      if (!mounted) return;

      Navigator.pushNamedAndRemoveUntil(
        context,
        AppConstants.loginRoute,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to log out: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoggingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = _authService.currentFirebaseUser?.uid;

    if (currentUserId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: const Center(child: Text('No active user session found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
            tooltip: 'Log Out',
            onPressed: _isLoggingOut ? null : _handleLogout,
          ),
        ],
      ),
      body: StreamBuilder<UserModel?>(
        stream: _userService.getUserStream(currentUserId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 48, color: AppTheme.errorColor),
                    const SizedBox(height: 12),
                    const Text('Error loading profile',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            );
          }

          final user = snapshot.data ??
              UserModel(
                id: currentUserId,
                name: _authService.currentFirebaseUser?.displayName ?? 'User',
                email: _authService.currentFirebaseUser?.email ?? '',
                isOnline: true,
              );

          final hasAvatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty;
          final isOnline = user.isOnline;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 10),

                  // Profile Picture with Online Status Badge & Edit icon
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 54,
                        backgroundColor:
                            AppTheme.primaryColor.withValues(alpha: 0.15),
                        backgroundImage:
                            hasAvatar ? NetworkImage(user.avatarUrl!) : null,
                        child: !hasAvatar
                            ? Text(
                                user.name.isNotEmpty
                                    ? user.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  fontSize: 42,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryColor,
                                ),
                              )
                            : null,
                      ),
                      // Status Dot
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: isOnline
                                ? AppTheme.accentColor
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.scaffoldBackgroundColor,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Name
                  Text(
                    user.name.isNotEmpty ? user.name : 'ConnectCall User',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),

                  // Email
                  Text(
                    user.email,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  // Online / Offline Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isOnline ? AppTheme.accentColor : Colors.grey)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          color: isOnline ? AppTheme.accentColor : Colors.grey,
                          size: 8,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isOnline ? 'Online' : 'Offline',
                          style: TextStyle(
                            color:
                                isOnline ? AppTheme.accentColor : Colors.grey,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Profile Details Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.person_outline,
                                color: AppTheme.primaryColor),
                          ),
                          title: const Text('Display Name',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            user.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.email_outlined,
                                color: AppTheme.primaryColor),
                          ),
                          title: const Text('Email Address',
                              style: TextStyle(fontSize: 12, color: Colors.grey)),
                          subtitle: Text(
                            user.email,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Edit Profile Button
                  CommonButton(
                    label: 'Edit Profile',
                    icon: Icons.edit_outlined,
                    onPressed: () => _showEditProfileModal(user),
                  ),
                  const SizedBox(height: 14),

                  // Log Out Button
                  CommonButton(
                    label: 'Log Out',
                    icon: Icons.logout_rounded,
                    isDestructive: true,
                    isLoading: _isLoggingOut,
                    onPressed: _isLoggingOut ? null : _handleLogout,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
