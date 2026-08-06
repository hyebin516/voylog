import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/recommendation_wizard_provider.dart';
import '../routes/app_routes.dart';
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
                '관심 있는 테마를 선택하세요 (복수 선택 가능)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final theme in RecommendationOptions.themes)
                    FilterChip(
                      key: Key('theme_$theme'),
                      label: Text(theme),
                      selected: wizard.selectedThemes.contains(theme),
                      onSelected: (_) => wizard.toggleTheme(theme),
                    ),
                ],
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
