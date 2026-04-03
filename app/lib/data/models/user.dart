class User {
  final int id;
  final String username;
  final String email;
  final String? fullName;
  final String targetExam;
  final DateTime? targetDate;
  final int dailyGoal;
  final bool isPremium;
  final bool isActive;
  final DateTime createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.fullName,
    required this.targetExam,
    this.targetDate,
    required this.dailyGoal,
    required this.isPremium,
    required this.isActive,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      fullName: json['full_name'],
      targetExam: json['target_exam'] ?? '执业医师',
      targetDate: json['target_date'] != null
          ? DateTime.parse(json['target_date'])
          : null,
      dailyGoal: json['daily_goal'] ?? 20,
      isPremium: json['is_premium'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'full_name': fullName,
      'target_exam': targetExam,
      'target_date': targetDate?.toIso8601String(),
      'daily_goal': dailyGoal,
      'is_premium': isPremium,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
