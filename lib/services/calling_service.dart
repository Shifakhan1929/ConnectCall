import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';
import '../models/user_model.dart';

class CallingService {
  static final CallingService _instance = CallingService._internal();
  factory CallingService() => _instance;
  CallingService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CallModel? _currentCall;
  CallModel? get currentCall => _currentCall;

  /// Placeholder to initiate an outgoing call (SDK integration in future phase)
  Future<CallModel> makeCall({
    required UserModel caller,
    required UserModel receiver,
    required CallType type,
  }) async {
    _currentCall = CallModel(
      callId: DateTime.now().millisecondsSinceEpoch.toString(),
      callerId: caller.id,
      callerName: caller.name,
      callerAvatar: caller.avatarUrl,
      receiverId: receiver.id,
      receiverName: receiver.name,
      receiverAvatar: receiver.avatarUrl,
      type: type,
      status: CallStatus.ringing,
      timestamp: DateTime.now(),
    );
    return _currentCall!;
  }

  /// Placeholder to accept incoming call
  Future<void> acceptCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.accepted);
    }
  }

  /// Placeholder to reject incoming call
  Future<void> rejectCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.rejected);
    }
  }

  /// Placeholder to terminate active call
  Future<void> endCall(String callId) async {
    if (_currentCall != null) {
      _currentCall = _currentCall!.copyWith(status: CallStatus.ended);
    }
  }

  void toggleMute({required bool isMuted}) {}

  void toggleCamera({required bool isCameraOff}) {}

  void switchCamera() {}

  /// Fetch call log history from Firestore calls collection
  Future<List<CallModel>> getCallHistory({String? userId}) async {
    if (!isFirebaseInitialized) return const [];

    try {
      final collection = _firestore.collection('calls');
      Query<Map<String, dynamic>> query = collection;

      if (userId != null) {
        query = query.where(
          Filter.or(
            Filter('callerId', isEqualTo: userId),
            Filter('receiverId', isEqualTo: userId),
          ),
        );
      }

      final snapshot = await query.orderBy('timestamp', descending: true).limit(20).get();
      return snapshot.docs.map((doc) => CallModel.fromMap(doc.data())).toList();
    } catch (e) {
      debugPrint('Notice: Call history fetch: $e');
      return const [];
    }
  }

  /// Real-time stream of call history
  Stream<List<CallModel>> getCallHistoryStream({String? userId}) {
    if (!isFirebaseInitialized) return const Stream.empty();

    try {
      final collection = _firestore.collection('calls');
      Query<Map<String, dynamic>> query = collection;

      if (userId != null) {
        query = query.where(
          Filter.or(
            Filter('callerId', isEqualTo: userId),
            Filter('receiverId', isEqualTo: userId),
          ),
        );
      }

      return query
          .orderBy('timestamp', descending: true)
          .limit(20)
          .snapshots()
          .map((snapshot) =>
              snapshot.docs.map((doc) => CallModel.fromMap(doc.data())).toList());
    } catch (e) {
      debugPrint('Notice: Call history stream: $e');
      return const Stream.empty();
    }
  }
}
