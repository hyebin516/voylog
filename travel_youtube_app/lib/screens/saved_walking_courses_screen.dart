import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/saved_walking_course_model.dart';
import '../providers/saved_walking_course_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

String _formatDuration(int? seconds) {
  if (seconds == null) return '-';
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  if (hours > 0) return '$hours시간 $minutes분';
  return '$minutes분';
}

String _formatDistance(int? meters) {
  if (meters == null) return '-';
  if (meters >= 1000) return '${(meters / 1000).toStringAsFixed(1)}km';
  return '${meters}m';
}

class SavedWalkingCoursesScreen extends StatefulWidget {
  const SavedWalkingCoursesScreen({super.key});

  @override
  State<SavedWalkingCoursesScreen> createState() => _SavedWalkingCoursesScreenState();
}

class _SavedWalkingCoursesScreenState extends State<SavedWalkingCoursesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SavedWalkingCourseProvider>().loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SavedWalkingCourseProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('내 코스 목록')),
      body: Builder(
        builder: (context) {
          if (provider.isLoading && provider.courses.isEmpty) {
            return const LoadingIndicator();
          }
          if (provider.state == ViewState.error && provider.courses.isEmpty) {
            return ErrorView(
              message: provider.errorMessage ?? '코스 목록을 불러오지 못했습니다.',
              onRetry: () => provider.loadCourses(),
            );
          }
          if (provider.courses.isEmpty) {
            return const Center(child: Text('저장된 코스가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: provider.courses.length,
            separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final SavedWalkingCourseModel course = provider.courses[index];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.savedWalkingCourseDetail, arguments: course),
                child: Row(
                  children: [
                    const Icon(Icons.directions_walk_rounded, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(course.region, style: Theme.of(context).textTheme.titleMedium),
                          Text(
                            '${_formatDistance(course.totalDistanceM)} · ${_formatDuration(course.totalDurationSec)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
