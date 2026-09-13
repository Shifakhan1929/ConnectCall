enum CallType { audio, video }

enum CallStatus { calling, ringing, connected, accepted, rejected, ended, missed, completed }

class CallModel {
  final String callId;
  final String channelId;
  final String callerId;
  final String callerName;
  final String? callerAvatar;
  final String receiverId;
  final String receiverName;
  final String? receiverAvatar;
  final CallType type;
  final CallStatus status;
  final DateTime timestamp;
  final DateTime? startedAt;
  final DateTime? connectedAt;
  final DateTime? endedAt;
  final int durationSeconds;

  const CallModel({
    required this.callId,
    String? channelId,
    required this.callerId,
    required this.callerName,
    this.callerAvatar,
    required this.receiverId,
    required this.receiverName,
    this.receiverAvatar,
    required this.type,
    required this.status,
    required this.timestamp,
    this.startedAt,
    this.connectedAt,
    this.endedAt,
    this.durationSeconds = 0,
  }) : channelId = channelId ?? 'call_$callId';

  Map<String, dynamic> toMap() {
    return {
      'callId': callId,
      'channelId': channelId,
      'callerId': callerId,
      'callerName': callerName,
      'callerAvatar': callerAvatar,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverAvatar': receiverAvatar,
      'participants': [callerId, receiverId],
      'type': type.name,
      'callType': type.name,
      'direction': 'outgoing',
      'status': status.name,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'createdAt': timestamp.millisecondsSinceEpoch,
      'startedAt': (startedAt ?? timestamp).millisecondsSinceEpoch,
      if (connectedAt != null) 'connectedAt': connectedAt!.millisecondsSinceEpoch,
      if (endedAt != null) 'endedAt': endedAt!.millisecondsSinceEpoch,
      'duration': durationSeconds,
      'durationSeconds': durationSeconds,
    };
  }

  factory CallModel.fromMap(Map<String, dynamic> map) {
    final callId = map['callId'] as String? ?? '';
    final channelId = (map['channelId'] as String?)?.isNotEmpty == true
        ? map['channelId'] as String
        : 'call_$callId';

    DateTime parseTimestamp(dynamic val, DateTime fallback) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is DateTime) return val;
      return fallback;
    }

    final createdAt = parseTimestamp(
      map['timestamp'] ?? map['createdAt'] ?? map['startedAt'],
      DateTime.now(),
    );

    DateTime? parseNullableTimestamp(dynamic val) {
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is DateTime) return val;
      return null;
    }

    return CallModel(
      callId: callId,
      channelId: channelId,
      callerId: map['callerId'] as String? ?? '',
      callerName: map['callerName'] as String? ?? '',
      callerAvatar: map['callerAvatar'] as String?,
      receiverId: map['receiverId'] as String? ?? '',
      receiverName: map['receiverName'] as String? ?? '',
      receiverAvatar: map['receiverAvatar'] as String?,
      type: CallType.values.firstWhere(
        (e) => e.name == (map['callType'] ?? map['type']),
        orElse: () => CallType.audio,
      ),
      status: CallStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CallStatus.calling,
      ),
      timestamp: createdAt,
      startedAt: parseNullableTimestamp(map['startedAt']) ?? createdAt,
      connectedAt: parseNullableTimestamp(map['connectedAt']),
      endedAt: parseNullableTimestamp(map['endedAt']),
      durationSeconds: (map['duration'] ?? map['durationSeconds']) as int? ?? 0,
    );
  }

  CallModel copyWith({
    String? callId,
    String? channelId,
    String? callerId,
    String? callerName,
    String? callerAvatar,
    String? receiverId,
    String? receiverName,
    String? receiverAvatar,
    CallType? type,
    CallStatus? status,
    DateTime? timestamp,
    DateTime? startedAt,
    DateTime? connectedAt,
    DateTime? endedAt,
    int? durationSeconds,
  }) {
    return CallModel(
      callId: callId ?? this.callId,
      channelId: channelId ?? this.channelId,
      callerId: callerId ?? this.callerId,
      callerName: callerName ?? this.callerName,
      callerAvatar: callerAvatar ?? this.callerAvatar,
      receiverId: receiverId ?? this.receiverId,
      receiverName: receiverName ?? this.receiverName,
      receiverAvatar: receiverAvatar ?? this.receiverAvatar,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      startedAt: startedAt ?? this.startedAt,
      connectedAt: connectedAt ?? this.connectedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  /// Whether the call was initiated by [currentUserId]
  bool isOutgoing(String currentUserId) => callerId == currentUserId;

  /// Call direction relative to [currentUserId]: 'outgoing' or 'incoming'
  String getDirection(String currentUserId) =>
      isOutgoing(currentUserId) ? 'outgoing' : 'incoming';

  /// Name of the other participant relative to [currentUserId]
  String getOtherPartyName(String currentUserId) =>
      isOutgoing(currentUserId) ? receiverName : callerName;

  /// Avatar URL of the other participant relative to [currentUserId]
  String? getOtherPartyAvatar(String currentUserId) =>
      isOutgoing(currentUserId) ? receiverAvatar : callerAvatar;

  /// User ID of the other participant relative to [currentUserId]
  String getOtherPartyId(String currentUserId) =>
      isOutgoing(currentUserId) ? receiverId : callerId;
}
