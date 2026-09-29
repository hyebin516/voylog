import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/custom_option_field.dart';
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
                '어디가 궁금하세요?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '관심있는 지역을 선택하면 관련 브이로그를 보여드려요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.md),
              // Above the chips, as in the handoff -- a typed region becomes
              // a chip in the list below, so the field reads as a way to add
              // to that list rather than an afterthought under it.
              CustomOptionField(
                key: const Key('customRegionField'),
                hintText: '찾는 지역을 직접 입력하세요',
                icon: Icons.edit_location_alt_outlined,
                onSubmitted: wizard.addRegion,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  // Typed-in regions join the list as chips, so they can be
                  // seen and unpicked the same way the offered ones are.
                  for (final region in [
                    ...RecommendationOptions.regions,
                    ...wizard.selectedRegions.where((r) => !RecommendationOptions.regions.contains(r)),
                  ])
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
                      // The handoff marks a picked chip with an ×, not a
                      // checkmark -- it also says how to unpick it.
                      showCheckmark: false,
                      onDeleted: wizard.selectedRegions.contains(region)
                          ? () => wizard.toggleRegion(region)
                          : null,
                      deleteIcon: const Icon(Icons.close_rounded, size: 15, color: Colors.white),
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
