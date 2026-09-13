import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import '../models/call_model.dart';

/// Dedicated service responsible for Firestore call history logs and persistence.
/// Keeps database signaling and logs separate from the Agora RTC media engine.
class CallHistoryService {
  static final CallHistoryService _instance = CallHistoryService._internal();
  factory CallHistoryService() => _instance;
  CallHistoryService._internal();

  bool get isFirebaseInitialized => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _callsCollection =>
      _firestore.collection('calls');

  /// Save or record a call log entry in Firestore.
  /// Uses merge to guarantee idempotency and prevent duplicate records.
  Future<void> logCall(CallModel call) async {
    if (!isFirebaseInitialized) return;

    try {
      await _callsCollection.doc(call.callId).set(
            call.toMap(),
            SetOptions(merge: true),
          );
      debugPrint('[CallHistoryService] Logged call ${call.callId} to Firestore.');
    } catch (e) {
      debugPrint('[CallHistoryService] Error logging call to Firestore: $e');
    }
  }

  /// Update an existing call log entry status (e.g. ended, rejected, missed)
  Future<void> updateCallStatus(
    String callId,
    CallStatus status, {
    int? durationSeconds,
    DateTime? endedAt,
  }) async {
    if (!isFirebaseInitialized) return;

    try {
      final updates = <String, dynamic>{
        'status': status.name,
      };
      if (durationSeconds != null) {
        updates['duration'] = durationSeconds;
        updates['durationSeconds'] = durationSeconds;
      }
      if (endedAt != null) {
        updates['endedAt'] = endedAt.millisecondsSinceEpoch;
      }
      await _callsCollection.doc(callId).update(updates);
      debugPrint('[CallHistoryService] Updated call $callId status to ${status.name}.');
    } catch (e) {
      debugPrint('[CallHistoryService] Error updating call status in Firestore: $e');
    }
  }

  /// Fetch call log history for a specific user with optional search and type filters
  Future<List<CallModel>> getCallHistory({
    String? userId,
    CallType? typeFilter,
    String? searchQuery,
    int limit = 50,
  }) async {
    if (!isFirebaseInitialized) return const [];

    try {
      Query<Map<String, dynamic>> query = _callsCollection;

      if (userId != null && userId.isNotEmpty) {
        query = query.where(
          Filter.or(
            Filter('callerId', isEqualTo: userId),
            Filter('receiverId', isEqualTo: userId),
            Filter('participants', arrayContains: userId),
          ),
        );
      }

      final snapshot = await query.limit(limit).get();
      var calls = snapshot.docs
          .map((doc) => CallModel.fromMap(doc.data()))
          .toList();

      // Sort newest first client-side to eliminate composite index requirement
      calls.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Apply type filter if provided
      if (typeFilter != null) {
        calls = calls.where((c) => c.type == typeFilter).toList();
      }

      // Apply search filter (by other party's name) if provided
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryLower = searchQuery.trim().toLowerCase();
        calls = calls.where((c) {
          final otherName =
              (c.callerId == userId ? c.receiverName : c.callerName).toLowerCase();
          return otherName.contains(queryLower);
        }).toList();
      }

      return calls;
    } catch (e) {
      debugPrint('[CallHistoryService] Notice: Call history fetch: $e');
      return const [];
    }
  }

  /// Real-time stream of call history logs with optional search and type filtering
  Stream<List<CallModel>> getCallHistoryStream({
    String? userId,
    CallType? typeFilter,
    String? searchQuery,
    int limit = 50,
  }) {
    if (!isFirebaseInitialized) return const Stream.empty();

    try {
      Query<Map<String, dynamic>> query = _callsCollection;

      if (userId != null && userId.isNotEmpty) {
        query = query.where(
          Filter.or(
            Filter('callerId', isEqualTo: userId),
            Filter('receiverId', isEqualTo: userId),
            Filter('participants', arrayContains: userId),
          ),
        );
      }

      return query.limit(limit).snapshots().map((snapshot) {
        var calls = snapshot.docs
            .map((doc) => CallModel.fromMap(doc.data()))
            .where((call) => call.callId.isNotEmpty)
            .toList();

        // 1. Sort newest first client-side so query doesn't require composite indexes
        calls.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        // 2. Filter by CallType (Audio or Video) if selected
        if (typeFilter != null) {
          calls = calls.where((c) => c.type == typeFilter).toList();
        }

        // 3. Filter by search query (user name of the other participant)
        if (searchQuery != null && searchQuery.trim().isNotEmpty) {
          final queryLower = searchQuery.trim().toLowerCase();
          calls = calls.where((c) {
            final otherName =
                (c.callerId == userId ? c.receiverName : c.callerName).toLowerCase();
            return otherName.contains(queryLower);
          }).toList();
        }

        return calls;
      });
    } catch (e) {
      debugPrint('[CallHistoryService] Notice: Call history stream: $e');
      return const Stream.empty();
    }
  }
}
