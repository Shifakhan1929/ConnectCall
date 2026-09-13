import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

class AuthService {
  // Singleton pattern for application-wide consistency
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  UserModel? _currentUser;

  // Getters
  UserModel? get currentUser => _currentUser;
  User? get currentFirebaseUser =>
      isFirebaseInitialized ? _auth.currentUser : null;
  bool get isAuthenticated =>
      isFirebaseInitialized && _auth.currentUser != null;
  Stream<User?> get authStateChanges =>
      isFirebaseInitialized ? _auth.authStateChanges() : const Stream.empty();

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  /// Check current auth status and load user profile from Firestore if authenticated
  Future<UserModel?> checkAuthState() async {
    try {
      if (!isFirebaseInitialized) {
        _currentUser = null;
        return null;
      }

      final firebaseUser = _auth.currentUser;
      if (firebaseUser == null) {
        _currentUser = null;
        return null;
      }

      final doc = await _usersCollection.doc(firebaseUser.uid).get();
      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromMap({
          ...doc.data()!,
          'id': firebaseUser.uid,
          'uid': firebaseUser.uid,
        });
        // Mark user as online on session restore
        await setUserOnlineStatus(true);
      } else {
        // Fallback if Firestore document was somehow missing
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          email: firebaseUser.email ?? '',
          avatarUrl: firebaseUser.photoURL,
          isOnline: true,
        );
        await _usersCollection.doc(firebaseUser.uid).set({
          ..._currentUser!.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      return _currentUser;
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      return null;
    }
  }

  /// Register a new user with Firebase Auth and store profile in Cloud Firestore
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    String? avatarUrl,
  }) async {
    if (!isFirebaseInitialized) {
      throw 'Firebase is not initialized. Please connect your Firebase project.';
    }
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('User creation failed. Please try again.');
      }

      // Update Firebase Auth display name
      await firebaseUser.updateDisplayName(name.trim());

      // Prepare Firestore user profile document
      final userModel = UserModel(
        id: firebaseUser.uid,
        name: name.trim(),
        email: email.trim(),
        avatarUrl: avatarUrl,
        isOnline: true,
      );

      await _usersCollection.doc(firebaseUser.uid).set({
        ...userModel.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'lastSeen': FieldValue.serverTimestamp(),
      });

      _currentUser = userModel;
      return userModel;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    } catch (e) {
      throw 'Registration failed: ${e.toString()}';
    }
  }

  /// Sign in user with Firebase Auth and update online status
  Future<UserModel> login({
    required String emailOrPhone,
    required String password,
  }) async {
    if (!isFirebaseInitialized) {
      throw 'Firebase is not initialized. Please connect your Firebase project.';
    }
    try {
      final trimmedInput = emailOrPhone.trim();

      // Firebase email/password login requires an email
      if (!trimmedInput.contains('@')) {
        throw 'Please enter a valid email address for login.';
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: trimmedInput,
        password: password,
      );

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        throw Exception('Login failed. Please verify your credentials.');
      }

      // Fetch user profile from Firestore
      final doc = await _usersCollection.doc(firebaseUser.uid).get();

      if (doc.exists && doc.data() != null) {
        _currentUser = UserModel.fromMap({
          ...doc.data()!,
          'id': firebaseUser.uid,
          'uid': firebaseUser.uid,
        });
      } else {
        _currentUser = UserModel(
          id: firebaseUser.uid,
          name: firebaseUser.displayName ?? firebaseUser.email?.split('@').first ?? 'User',
          email: firebaseUser.email ?? trimmedInput,
          isOnline: true,
        );
        await _usersCollection.doc(firebaseUser.uid).set({
          ..._currentUser!.toMap(),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      // Mark user as online in Firestore
      await setUserOnlineStatus(true);

      return _currentUser!;
    } on FirebaseAuthException catch (e) {
      throw getReadableAuthError(e);
    } catch (e) {
      if (e is String) rethrow;
      throw 'Login failed: ${e.toString()}';
    }
  }

  /// Sign out current user and set online status to false
  Future<void> logout() async {
    if (!isFirebaseInitialized) {
      _currentUser = null;
      return;
    }
    try {
      final firebaseUser = _auth.currentUser;
      if (firebaseUser != null) {
        await setUserOnlineStatus(false);
      }
      await _auth.signOut();
      _currentUser = null;
    } catch (e) {
      debugPrint('Error during logout: $e');
      // Ensure local state and sign out are still executed
      await _auth.signOut();
      _currentUser = null;
    }
  }

  /// Update online presence in Cloud Firestore
  Future<void> setUserOnlineStatus(bool isOnline) async {
    if (!isFirebaseInitialized) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      await _usersCollection.doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(isOnline: isOnline);
      }
    } catch (e) {
      debugPrint('Failed to update online status: $e');
    }
  }

  /// Translates Firebase auth exceptions to user-friendly messages
  static String getReadableAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please verify your credentials.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase Console.';
      default:
        return e.message ?? 'An unexpected authentication error occurred.';
    }
  }
}
