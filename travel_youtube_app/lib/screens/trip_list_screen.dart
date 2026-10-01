import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/trip_model.dart';
import '../providers/auth_provider.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../utils/date_format.dart';
import '../utils/view_state.dart';
import '../widgets/date_range_dialog.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/login_required_card.dart';
import '../widgets/voylog_logo.dart';

class TripListScreen extends StatefulWidget {
  /// True when this screen is the "여행" bottom-tab root (inside
  /// [AppBottomNavShell]'s IndexedStack, switching tabs is the way "back").
  /// False when pushed directly on top of another screen (e.g. from the
  /// "이 폴더로 동선 생성하기" shortcut) -- that needs an explicit back
  /// button since there's no tab bar to fall back on.
  final bool isTabRoot;

  const TripListScreen({super.key, this.isTabRoot = false});

  @override
  State<TripListScreen> createState() => _TripListScreenState();
}

class _TripListScreenState extends State<TripListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isAuthenticated) {
        context.read<TripProvider>().loadTrips();
      }
    });
  }

  Future<void> _createTrip() async {
    final nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    final result = await showDialog<_NewTripResult>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          Future<void> pickDateRange() async {
            final picked = await showTripDateRangeDialog(
              dialogContext,
              initialStartDate: startDate,
              initialEndDate: endDate,
              title: '새 여행 날짜',
            );
            if (picked == null) return;
            setDialogState(() {
              startDate = picked.startDate;
              endDate = picked.endDate;
            });
          }

          return AlertDialog(
            title: const Text('새 여행 만들기'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(hintText: '예: 제주도 여행'),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: pickDateRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    startDate != null && endDate != null
                        ? '${formatTripDate(startDate!)} – ${formatTripDate(endDate!)}'
                        : '여행 날짜 선택',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed:
                    (nameController.text.trim().isNotEmpty &&
                        startDate != null &&
                        endDate != null)
                    ? () => Navigator.pop(
                        dialogContext,
                        _NewTripResult(
                          nameController.text.trim(),
                          startDate,
                          endDate,
                        ),
                      )
                    : null,
                child: const Text('만들기'),
              ),
            ],
          );
        },
      ),
    );
    if (result == null || result.name.isEmpty || !mounted) return;

    final tripProvider = context.read<TripProvider>();
    final trip = await tripProvider.createTrip(
      result.name,
      startDate: result.startDate,
      endDate: result.endDate,
    );
    if (!mounted) return;

    if (trip != null) {
      Navigator.pushNamed(
        context,
        AppRoutes.tripDetail,
        arguments: trip.tripId,
      );
    } else {
      final message = tripProvider.errorMessage ?? '여행 생성에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  Future<void> _confirmDeleteTrip(TripModel trip) async {
    final tripProvider = context.read<TripProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('여행 삭제'),
        content: Text('${trip.name} 여행을 삭제하시겠습니까? 저장된 날짜별 동선도 함께 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await tripProvider.deleteTrip(trip.tripId);
    if (!success && mounted) {
      final message = tripProvider.errorMessage ?? '여행 삭제에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final tripProvider = context.watch<TripProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  if (!widget.isTabRoot) ...[
                    InkWell(
                      onTap: () => Navigator.of(context).maybePop(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 17,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Expanded(
                    child: Text(
                      '여행',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
                  if (authProvider.isAuthenticated)
                    InkWell(
                      onTap: _createTrip,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                      child: Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                          boxShadow: AppColors.primaryShadow(),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (!authProvider.isAuthenticated) {
                    return const LoginRequiredCard(
                      message: '여행 일정을 만들고 관리하려면\n로그인이 필요해요',
                    );
                  }
                  if (tripProvider.isLoading && tripProvider.trips.isEmpty) {
                    return const LoadingIndicator();
                  }
                  if (tripProvider.state == ViewState.error &&
                      tripProvider.trips.isEmpty) {
                    return ErrorView(
                      message:
                          tripProvider.errorMessage ?? '여행 목록을 불러오지 못했습니다.',
                      onRetry: () => tripProvider.loadTrips(),
                    );
                  }
                  if (tripProvider.trips.isEmpty) {
                    return const Center(
                      child: Text(
                        '아직 만든 여행이 없습니다.',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    // One extra row at the top: the handoff's "내 여행 파일
                    // N개" line, which sits with the list rather than in the
                    // header so it scrolls away with it.
                    itemCount: tripProvider.trips.length + 1,
                    separatorBuilder: (context, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Text(
                          '내 여행 파일 ${tripProvider.trips.length}개',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textTertiary,
                          ),
                        );
                      }
                      final TripModel trip = tripProvider.trips[index - 1];
                      return InkWell(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.tripDetail,
                          arguments: trip.tripId,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: AppColors.cardShadow(),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceTint3,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const MountainGlyphIcon(
                                  size: 21,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      trip.name,
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${trip.dayCount}일차 저장됨',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () => _confirmDeleteTrip(trip),
                                borderRadius: BorderRadius.circular(999),
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  alignment: Alignment.center,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFDF1F0),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.delete_outline_rounded,
                                    size: 17,
                                    color: AppColors.danger,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

class _NewTripResult {
  const _NewTripResult(this.name, this.startDate, this.endDate);

  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
}
