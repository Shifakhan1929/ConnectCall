import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';

/// CallSignalingService encapsulates all Cloud Firestore signaling for audio calls.
/// Keeps database signaling and live call status sync strictly isolated from Agora media logic.
class CallSignalingService {
  static final CallSignalingService _instance = CallSignalingService._internal();
  factory CallSignalingService() => _instance;
  CallSignalingService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  /// Initiate an outgoing 1-to-1 call document in Firestore
  Future<CallModel> initiateCall({
    required UserModel caller,
    required UserModel receiver,
    CallType type = CallType.audio,
  }) async {
    if (!isFirebaseInitialized) {
      throw 'Firebase is not initialized. Cannot initiate call signaling.';
    }

    final now = DateTime.now();
    final callId = '${now.millisecondsSinceEpoch}_${caller.id.substring(0, caller.id.length > 4 ? 4 : caller.id.length)}';
    final channelId = 'channel_$callId';

    final call = CallModel(
      callId: callId,
      channelId: channelId,
      callerId: caller.id,
      callerName: caller.name,
      callerAvatar: caller.avatarUrl,
      receiverId: receiver.id,
      receiverName: receiver.name,
      receiverAvatar: receiver.avatarUrl,
      type: type,
      status: CallStatus.calling,
      timestamp: now,
      startedAt: now,
      durationSeconds: 0,
    );

    try {
      await _callsCollection.doc(callId).set({
        ...call.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'startedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Call document created: $callId in channel $channelId');
      return call;
    } catch (e) {
      debugPrint('Error creating call document in Firestore: $e');
      rethrow;
    }
  }

  /// Real-time stream of an active call document by its call ID
  Stream<CallModel?> listenToCall(String callId) {
    if (!isFirebaseInitialized) return const Stream.empty();

    return _callsCollection.doc(callId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return CallModel.fromMap(doc.data()!);
    });
  }

  /// Listen for incoming calls addressed to the specified user
  Stream<CallModel?> listenForIncomingCalls(String userId) {
    if (!isFirebaseInitialized) return const Stream.empty();

    return _callsCollection
        .where('receiverId', isEqualTo: userId)
        .where('status', isEqualTo: 'calling')
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) return null;

      // Filter for recent incoming calls (created within the last 60 seconds)
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final timestamp = data['createdAt'] ?? data['timestamp'] ?? data['startedAt'];
        int? millis;
        if (timestamp is Timestamp) {
          millis = timestamp.millisecondsSinceEpoch;
        } else if (timestamp is int) {
          millis = timestamp;
        }

        if (millis == null || (now - millis).abs() < 60000) {
          return CallModel.fromMap(data);
        }
      }
      return null;
    });
  }

  /// Accept an incoming call (changes status to 'connected')
  Future<void> acceptCall(String callId) async {
    if (!isFirebaseInitialized) return;

    try {
      await _callsCollection.doc(callId).update({
        'status': CallStatus.connected.name,
        'connectedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Call $callId accepted and marked connected.');
    } catch (e) {
      debugPrint('Error accepting call in Firestore: $e');
    }
  }

  /// Decline / reject an incoming call (changes status to 'rejected')
  Future<void> rejectCall(String callId) async {
    if (!isFirebaseInitialized) return;

    try {
      await _callsCollection.doc(callId).update({
        'status': CallStatus.rejected.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('Call $callId rejected.');
    } catch (e) {
      debugPrint('Error rejecting call in Firestore: $e');
    }
  }

  /// End an active call (changes status to 'ended')
  Future<void> endCall({
    required String callId,
    int durationSeconds = 0,
  }) async {
    if (!isFirebaseInitialized) return;

    try {
      await _callsCollection.doc(callId).update({
        'status': CallStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
        'duration': durationSeconds,
        'durationSeconds': durationSeconds,
      });
      debugPrint('Call $callId ended with duration $durationSeconds s.');
    } catch (e) {
      debugPrint('Error ending call in Firestore: $e');
    }
  }
}
