import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/recommendation_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/walking_course_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class WalkingCourseRegionScreen extends StatefulWidget {
  const WalkingCourseRegionScreen({super.key});

  @override
  State<WalkingCourseRegionScreen> createState() => _WalkingCourseRegionScreenState();
}

class _WalkingCourseRegionScreenState extends State<WalkingCourseRegionScreen> {
  String? _selectedRegion;

  Future<void> _onGeneratePressed(BuildContext context) async {
    final region = _selectedRegion;
    if (region == null) return;

    final provider = context.read<WalkingCourseProvider>();
    await provider.generate(region);

    if (!context.mounted) return;
    Navigator.pushNamed(context, AppRoutes.walkingCourseResult);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<WalkingCourseProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('뚜벅이 코스')),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '지역을 고르면 걸어서 둘러볼 수 있는 코스를 만들어 드려요',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final region in RecommendationOptions.regions)
                    ChoiceChip(
                      key: Key('walkingCourseRegion_$region'),
                      label: Text(region),
                      selected: _selectedRegion == region,
                      onSelected: (_) => setState(() => _selectedRegion = region),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const Key('generateCourseButton'),
                label: '코스 만들기',
                icon: Icons.directions_walk_rounded,
                isLoading: isLoading,
                onPressed: _selectedRegion != null ? () => _onGeneratePressed(context) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
