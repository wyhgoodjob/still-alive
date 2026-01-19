/// Emergency contact model
class EmergencyContact {
  final String? id;
  final String userId;
  final String name;
  final String phoneNumber;
  final String? relationship;
  final int priority;
  final DateTime? createdAt;

  EmergencyContact({
    this.id,
    required this.userId,
    required this.name,
    required this.phoneNumber,
    this.relationship,
    this.priority = 1,
    this.createdAt,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      phoneNumber: json['phone_number'] as String,
      relationship: json['relationship'] as String?,
      priority: json['priority'] as int? ?? 1,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'relationship': relationship,
      'priority': priority,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
  
  /// Create a copy for inserting (without id)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'name': name,
      'phone_number': phoneNumber,
      'relationship': relationship,
      'priority': priority,
    };
  }
  
  EmergencyContact copyWith({
    String? id,
    String? userId,
    String? name,
    String? phoneNumber,
    String? relationship,
    int? priority,
    DateTime? createdAt,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      relationship: relationship ?? this.relationship,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
