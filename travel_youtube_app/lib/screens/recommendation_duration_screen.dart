import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class RecommendationDurationScreen extends StatelessWidget {
  const RecommendationDurationScreen({super.key});

  Future<void> _onSearchPressed(BuildContext context, RecommendationWizardProvider wizard) async {
    final videoProvider = context.read<VideoProvider>();
    await videoProvider.searchByRecommendation(
      regions: wizard.selectedRegions.toList(),
      themes: wizard.selectedThemes.toList(),
      duration: wizard.selectedDuration!,
    );

    if (!context.mounted) return;
    Navigator.pushNamed(context, AppRoutes.recommendationResults);
  }

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<RecommendationWizardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('기간 선택')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '여행 기간을 선택하세요',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final duration in RecommendationOptions.durations)
                    ChoiceChip(
                      key: Key('duration_$duration'),
                      label: Text(
                        duration,
                        style: TextStyle(
                          color: wizard.selectedDuration == duration ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: wizard.selectedDuration == duration,
                      selectedColor: AppColors.primary,
                      onSelected: (_) => wizard.selectDuration(duration),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('durationSearchButton'),
                label: '추천 받기',
                isLoading: context.watch<VideoProvider>().isSearching,
                onPressed: wizard.canSearch ? () => _onSearchPressed(context, wizard) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
