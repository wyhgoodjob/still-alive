/// Check-in history entry model
class CheckIn {
  final String id;
  final String userId;
  final DateTime checkInTime;
  final String method;

  CheckIn({
    required this.id,
    required this.userId,
    required this.checkInTime,
    this.method = 'manual',
  });

  factory CheckIn.fromJson(Map<String, dynamic> json) {
    return CheckIn(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      checkInTime: DateTime.parse(json['check_in_time'] as String),
      method: json['method'] as String? ?? 'manual',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'check_in_time': checkInTime.toIso8601String(),
      'method': method,
    };
  }
}
