/// 알림 설정 모델
class NotificationSettings {
  /// 전체 알림 on/off
  final bool enabled;

  /// 채팅 알림
  final bool chatEnabled;

  /// 할일 알림
  final bool todoEnabled;

  /// 일정 알림
  final bool eventEnabled;

  const NotificationSettings({
    this.enabled = true,
    this.chatEnabled = true,
    this.todoEnabled = true,
    this.eventEnabled = true,
  });

  factory NotificationSettings.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const NotificationSettings();
    }
    return NotificationSettings(
      enabled: data['enabled'] ?? true,
      chatEnabled: data['chatEnabled'] ?? true,
      todoEnabled: data['todoEnabled'] ?? true,
      eventEnabled: data['eventEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'chatEnabled': chatEnabled,
      'todoEnabled': todoEnabled,
      'eventEnabled': eventEnabled,
    };
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? chatEnabled,
    bool? todoEnabled,
    bool? eventEnabled,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      chatEnabled: chatEnabled ?? this.chatEnabled,
      todoEnabled: todoEnabled ?? this.todoEnabled,
      eventEnabled: eventEnabled ?? this.eventEnabled,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NotificationSettings &&
        other.enabled == enabled &&
        other.chatEnabled == chatEnabled &&
        other.todoEnabled == todoEnabled &&
        other.eventEnabled == eventEnabled;
  }

  @override
  int get hashCode =>
      enabled.hashCode ^
      chatEnabled.hashCode ^
      todoEnabled.hashCode ^
      eventEnabled.hashCode;
}
