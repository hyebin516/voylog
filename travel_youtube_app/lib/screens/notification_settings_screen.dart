import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/notification_settings_provider.dart';
import '../utils/view_state.dart';
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('알림 설정', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: Builder(
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
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    children: [
                      _NotificationRow(
                        child: SwitchListTile(
                          key: const Key('allAlertsSwitch'),
                          activeThumbColor: AppColors.primary,
                          title: const Text('전체 알림', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          subtitle: const Text('모든 알림을 한번에 켜고 끌 수 있어요', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          value: settings.allEnabled,
                          onChanged: provider.isSaving ? null : (value) => provider.updateAll(value),
                        ),
                      ),
                      const _SectionLabel('여행 알림'),
                      _NotificationRow(
                        child: SwitchListTile(
                          key: const Key('tripStartAlertsSwitch'),
                          activeThumbColor: AppColors.primary,
                          title: const Text('여행 시작 알림', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          subtitle: const Text('여행 시작 하루 전에 알려드려요', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          value: settings.tripStartAlerts,
                          onChanged: provider.isSaving ? null : (value) => provider.updateTripStartAlerts(value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NotificationRow(
                        child: SwitchListTile(
                          key: const Key('routeCompleteAlertsSwitch'),
                          activeThumbColor: AppColors.primary,
                          title: const Text('동선 생성 완료', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          value: settings.routeCompleteAlerts,
                          onChanged: provider.isSaving ? null : (value) => provider.updateRouteCompleteAlerts(value),
                        ),
                      ),
                      const _SectionLabel('기타'),
                      _NotificationRow(
                        child: SwitchListTile(
                          key: const Key('marketingAlertsSwitch'),
                          activeThumbColor: AppColors.primary,
                          title: const Text('이벤트 및 마케팅 정보', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          value: settings.marketingAlerts,
                          onChanged: provider.isSaving ? null : (value) => provider.updateMarketingAlerts(value),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _NotificationRow(
                        child: SwitchListTile(
                          key: const Key('nightSilentSwitch'),
                          activeThumbColor: AppColors.primary,
                          title: const Text('야간 알림 받지 않기', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          value: settings.nightSilent,
                          onChanged: provider.isSaving ? null : (value) => provider.updateNightSilent(value),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Material, not a colored Container: the switch tile paints its tap
    // ripple on the nearest Material, which a colored Container would hide.
    return Material(
      color: AppColors.surfaceTint1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE3F0F8), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
