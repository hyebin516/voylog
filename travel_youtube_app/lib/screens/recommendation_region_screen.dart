import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class RecommendationRegionScreen extends StatelessWidget {
  const RecommendationRegionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<RecommendationWizardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('지역 선택')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '가고 싶은 지역을 선택하세요 (복수 선택 가능)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final region in RecommendationOptions.regions)
                    FilterChip(
                      key: Key('region_$region'),
                      label: Text(
                        region,
                        style: TextStyle(
                          color: wizard.selectedRegions.contains(region) ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: wizard.selectedRegions.contains(region),
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => wizard.toggleRegion(region),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('regionNextButton'),
                label: '다음 (${wizard.selectedRegions.length}개 선택됨)',
                onPressed: wizard.canProceedFromRegions
                    ? () => Navigator.pushNamed(context, AppRoutes.recommendationTheme)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
