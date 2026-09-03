import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/notification_settings_provider.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationSettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationSettingsProvider>();
    final settings = provider.settings;

    return Scaffold(
      appBar: AppBar(title: const Text('알림 설정')),
      body: Builder(
        builder: (context) {
          if (provider.isLoading && settings == null) {
            return const LoadingIndicator();
          }
          if (provider.state == ViewState.error && settings == null) {
            return ErrorView(
              message: provider.errorMessage ?? '알림 설정을 불러오지 못했습니다.',
              onRetry: () => provider.loadSettings(),
            );
          }
          if (settings == null) return const SizedBox.shrink();

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      key: const Key('tripAlertsSwitch'),
                      activeThumbColor: AppColors.primary,
                      title: const Text('여행 일정 알림'),
                      subtitle: const Text('저장한 여행/동선 관련 알림을 받습니다.'),
                      value: settings.tripAlerts,
                      onChanged: provider.isSaving ? null : (value) => provider.updateTripAlerts(value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      key: const Key('serviceAlertsSwitch'),
                      activeThumbColor: AppColors.primary,
                      title: const Text('서비스 알림'),
                      subtitle: const Text('새 기능, 점검 등 서비스 관련 알림을 받습니다.'),
                      value: settings.serviceAlerts,
                      onChanged: provider.isSaving ? null : (value) => provider.updateServiceAlerts(value),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      key: const Key('marketingAlertsSwitch'),
                      activeThumbColor: AppColors.primary,
                      title: const Text('마케팅 정보 수신'),
                      subtitle: const Text('이벤트, 혜택 등 마케팅 정보를 받습니다.'),
                      value: settings.marketingAlerts,
                      onChanged: provider.isSaving ? null : (value) => provider.updateMarketingAlerts(value),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
