enum CrmNotificationLevel { info, success, warning, error }

class CrmNotification {
  CrmNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.level,
    required this.createdAt,
    this.read = false,
  });

  final String id;
  final String title;
  final String message;
  final CrmNotificationLevel level;
  final String createdAt;
  bool read;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'level': level.name,
    'createdAt': createdAt,
    'read': read,
  };

  factory CrmNotification.fromJson(Map<String, dynamic> json) {
    final level = CrmNotificationLevel.values.firstWhere(
      (value) => value.name == json['level']?.toString(),
      orElse: () => CrmNotificationLevel.info,
    );
    return CrmNotification(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      level: level,
      createdAt: json['createdAt']?.toString() ?? '',
      read: json['read'] == true,
    );
  }
}
