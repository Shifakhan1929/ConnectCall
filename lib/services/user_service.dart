import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class UserService {
  static final UserService _instance = UserService._internal();
  factory UserService() => _instance;
  UserService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Real-time stream of all registered users, optionally excluding the current user
  Stream<List<UserModel>> getUsersStream({String? excludeUserId}) {
    if (!isFirebaseInitialized) {
      return const Stream.empty();
    }

    return _usersCollection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return UserModel.fromMap({
              ...data,
              'id': doc.id,
              'uid': doc.id,
            });
          })
          .where((user) => excludeUserId == null || user.id != excludeUserId)
          .toList();
    });
  }

  /// One-time fetch of all registered users
  Future<List<UserModel>> getUsers({String? excludeUserId}) async {
    if (!isFirebaseInitialized) return [];

    try {
      final snapshot = await _usersCollection.get();
      return snapshot.docs
          .map((doc) {
            final data = doc.data();
            return UserModel.fromMap({
              ...data,
              'id': doc.id,
              'uid': doc.id,
            });
          })
          .where((user) => excludeUserId == null || user.id != excludeUserId)
          .toList();
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  /// Search users by name or email
  Future<List<UserModel>> searchUsers(
    String query, {
    String? excludeUserId,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) {
      return getUsers(excludeUserId: excludeUserId);
    }

    final allUsers = await getUsers(excludeUserId: excludeUserId);
    return allUsers.where((user) {
      final nameMatches = user.name.toLowerCase().contains(cleanQuery);
      final emailMatches = user.email.toLowerCase().contains(cleanQuery);
      return nameMatches || emailMatches;
    }).toList();
  }

  /// Fetch a specific user by document ID
  Future<UserModel?> getUserById(String userId) async {
    if (!isFirebaseInitialized) return null;

    try {
      final doc = await _usersCollection.doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromMap({
        ...doc.data()!,
        'id': doc.id,
        'uid': doc.id,
      });
    } catch (e) {
      debugPrint('Error fetching user by ID: $e');
      return null;
    }
  }

  /// Update online/offline status in Cloud Firestore
  Future<void> updateUserStatus({
    required String userId,
    required bool isOnline,
  }) async {
    if (!isFirebaseInitialized) return;

    try {
      await _usersCollection.doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating user status: $e');
    }
  }

  /// Update user profile details
  Future<void> updateUserProfile(UserModel user) async {
    if (!isFirebaseInitialized) return;

    try {
      await _usersCollection.doc(user.id).update(user.toMap());
    } catch (e) {
      debugPrint('Error updating user profile: $e');
    }
  }
}
