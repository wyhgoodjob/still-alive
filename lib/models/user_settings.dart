import '../core/constants.dart';

/// User settings model
class UserSettings {
  final String userId;
  final int checkInIntervalHours;
  final String alertMessage;
  final DateTime? lastCheckIn;
  final bool alertSent;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserSettings({
    required this.userId,
    this.checkInIntervalHours = AppConstants.defaultCheckInIntervalHours,
    this.alertMessage = AppConstants.defaultAlertMessage,
    this.lastCheckIn,
    this.alertSent = false,
    this.timezone = 'UTC',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      userId: json['user_id'] as String,
      checkInIntervalHours: json['check_in_interval_hours'] as int? ?? AppConstants.defaultCheckInIntervalHours,
      alertMessage: json['alert_message'] as String? ?? AppConstants.defaultAlertMessage,
      lastCheckIn: json['last_check_in'] != null 
          ? DateTime.parse(json['last_check_in'] as String)
          : null,
      alertSent: json['alert_sent'] as bool? ?? false,
      timezone: json['timezone'] as String? ?? 'UTC',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'check_in_interval_hours': checkInIntervalHours,
      'alert_message': alertMessage,
      'last_check_in': lastCheckIn?.toIso8601String(),
      'alert_sent': alertSent,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  /// Calculate the deadline for next check-in
  DateTime? get nextCheckInDeadline {
    if (lastCheckIn == null) return null;
    return lastCheckIn!.add(Duration(hours: checkInIntervalHours));
  }
  
  /// Calculate remaining time until deadline
  Duration? get timeRemaining {
    final deadline = nextCheckInDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
  
  /// Check if user is overdue
  bool get isOverdue {
    final remaining = timeRemaining;
    return remaining != null && remaining == Duration.zero;
  }
  
  UserSettings copyWith({
    String? userId,
    int? checkInIntervalHours,
    String? alertMessage,
    DateTime? lastCheckIn,
    bool? alertSent,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserSettings(
      userId: userId ?? this.userId,
      checkInIntervalHours: checkInIntervalHours ?? this.checkInIntervalHours,
      alertMessage: alertMessage ?? this.alertMessage,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      alertSent: alertSent ?? this.alertSent,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
