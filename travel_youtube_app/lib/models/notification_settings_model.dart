class NotificationSettingsModel {
  final bool newVlogAlerts;
  final bool routeCompleteAlerts;
  final bool marketingAlerts;
  final bool nightSilent;

  const NotificationSettingsModel({
    required this.newVlogAlerts,
    required this.routeCompleteAlerts,
    required this.marketingAlerts,
    required this.nightSilent,
  });

  /// UI-only derived state for the design's "전체 알림" master toggle --
  /// deliberately not backed by its own DB column so there's only one
  /// source of truth (see CLAUDE.md's `notification_settings` note).
  bool get allEnabled => newVlogAlerts && routeCompleteAlerts && marketingAlerts && !nightSilent;

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      newVlogAlerts: json['newVlogAlerts'] as bool,
      routeCompleteAlerts: json['routeCompleteAlerts'] as bool,
      marketingAlerts: json['marketingAlerts'] as bool,
      nightSilent: json['nightSilent'] as bool,
    );
  }

  NotificationSettingsModel copyWith({
    bool? newVlogAlerts,
    bool? routeCompleteAlerts,
    bool? marketingAlerts,
    bool? nightSilent,
  }) {
    return NotificationSettingsModel(
      newVlogAlerts: newVlogAlerts ?? this.newVlogAlerts,
      routeCompleteAlerts: routeCompleteAlerts ?? this.routeCompleteAlerts,
      marketingAlerts: marketingAlerts ?? this.marketingAlerts,
      nightSilent: nightSilent ?? this.nightSilent,
    );
  }
}
