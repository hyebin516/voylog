import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/taste_preference_options.dart';
import '../core/theme/app_theme.dart';
import '../providers/taste_preference_provider.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class TastePreferenceScreen extends StatefulWidget {
  const TastePreferenceScreen({super.key});

  @override
  State<TastePreferenceScreen> createState() => _TastePreferenceScreenState();
}

class _TastePreferenceScreenState extends State<TastePreferenceScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TastePreferenceProvider>().loadPreferences();
    });
  }

  Future<void> _onSavePressed(TastePreferenceProvider provider) async {
    final success = await provider.save();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취향이 저장되었습니다.')));
  }

  Future<void> _onResetPressed(TastePreferenceProvider provider) async {
    final success = await provider.reset();
    if (!mounted || !success) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('취향 설정이 초기화되었습니다.')));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TastePreferenceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('취향 설정'),
        actions: [
          TextButton(
            key: const Key('tastePreferenceResetButton'),
            onPressed: provider.isSaving ? null : () => _onResetPressed(provider),
            child: const Text('초기화'),
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (provider.isLoading) {
            return const LoadingIndicator();
          }
          if (provider.state == ViewState.error && provider.selectedTags.isEmpty) {
            return ErrorView(
              message: provider.errorMessage ?? '취향 정보를 불러오지 못했습니다.',
              onRetry: () => provider.loadPreferences(),
            );
          }

          return SingleChildScrollView(
            child: ResponsiveCenter(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('취향에 맞는 태그를 선택해 주세요', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '선택한 취향을 바탕으로 내 주변 추천 결과가 더 정확해져요. 건너뛰어도 추천은 계속 이용할 수 있어요.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: [
                      for (final tag in TastePreferenceOptions.tags)
                        FilterChip(
                          key: Key('tastePreference_$tag'),
                          label: Text(
                            tag,
                            style: TextStyle(
                              color: provider.selectedTags.contains(tag) ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          selected: provider.selectedTags.contains(tag),
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          onSelected: (_) => provider.toggleTag(tag),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  PrimaryButton(
                    key: const Key('tastePreferenceSaveButton'),
                    label: '저장하기 (${provider.selectedTags.length}개 선택됨)',
                    isLoading: provider.isSaving,
                    onPressed: provider.selectedTags.isEmpty ? null : () => _onSavePressed(provider),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
