class NotificationSettingsModel {
  final bool tripAlerts;
  final bool serviceAlerts;
  final bool marketingAlerts;

  const NotificationSettingsModel({
    required this.tripAlerts,
    required this.serviceAlerts,
    required this.marketingAlerts,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      tripAlerts: json['tripAlerts'] as bool,
      serviceAlerts: json['serviceAlerts'] as bool,
      marketingAlerts: json['marketingAlerts'] as bool,
    );
  }

  NotificationSettingsModel copyWith({
    bool? tripAlerts,
    bool? serviceAlerts,
    bool? marketingAlerts,
  }) {
    return NotificationSettingsModel(
      tripAlerts: tripAlerts ?? this.tripAlerts,
      serviceAlerts: serviceAlerts ?? this.serviceAlerts,
      marketingAlerts: marketingAlerts ?? this.marketingAlerts,
    );
  }
}
