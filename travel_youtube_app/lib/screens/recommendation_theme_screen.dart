import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/custom_option_field.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class RecommendationThemeScreen extends StatelessWidget {
  const RecommendationThemeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final wizard = context.watch<RecommendationWizardProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('테마 선택')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '어떤 느낌이 좋으세요?',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '원하는 여행 테마를 골라주세요',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary.withValues(alpha: 0.55)),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  // Same as the region step: a typed theme becomes a chip.
                  for (final theme in [
                    ...RecommendationOptions.themes,
                    ...wizard.selectedThemes.where((t) => !RecommendationOptions.themes.contains(t)),
                  ])
                    FilterChip(
                      key: Key('theme_$theme'),
                      label: Text(
                        theme,
                        style: TextStyle(
                          color: wizard.selectedThemes.contains(theme) ? Colors.white : AppColors.ink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      selected: wizard.selectedThemes.contains(theme),
                      selectedColor: AppColors.primary,
                      checkmarkColor: Colors.white,
                      onSelected: (_) => wizard.toggleTheme(theme),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              CustomOptionField(
                key: const Key('customThemeField'),
                hintText: '찾는 테마가 없다면 직접 입력 (예: 야경)',
                icon: Icons.edit_outlined,
                onSubmitted: wizard.addTheme,
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('themeNextButton'),
                label: '다음 (${wizard.selectedThemes.length}개 선택됨)',
                onPressed: wizard.canProceedFromThemes
                    ? () => Navigator.pushNamed(context, AppRoutes.recommendationDuration)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
