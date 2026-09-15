import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/start_point_model.dart';
import '../providers/walking_course_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class WalkingCourseRegionScreen extends StatefulWidget {
  const WalkingCourseRegionScreen({super.key});

  @override
  State<WalkingCourseRegionScreen> createState() =>
      _WalkingCourseRegionScreenState();
}

/// Mood/walking-duration filters shown in the design handoff. Both are
/// forwarded to `POST /recommendations/walking-course` (FR-17 extension):
/// mood boosts candidates tagged with the matching mood tag
/// (`WALKING_COURSE_MOOD_TAG_MAP` in ai-worker's tag_catalog.py), and
/// walkDuration adjusts the target stop count / walkable-distance budget
/// (`_DURATION_PROFILES` in walking_course_service.py).
/// Walkable-neighborhood options shown in the design handoff for this
/// screen -- distinct from the province/city list used by the video
/// recommendation wizard, since a walking course needs a small, genuinely
/// walkable area rather than a whole city/province.
const List<String> _walkingCourseRegions = [
  '전주 한옥마을',
  '서울 성수',
  '부산 전포',
  '경주 황리단길',
  '제주 원도심',
  '강릉 초당',
];

const List<String> _walkingCourseMoods = [
  '조용한',
  '활기찬',
  '감성적인',
  '힙한',
  '전통적인',
  '로컬스러운',
];
const List<String> _walkingCourseDurations = ['1시간 이내', '2~3시간', '반나절'];

class _WalkingCourseRegionScreenState extends State<WalkingCourseRegionScreen> {
  String? _selectedRegion;
  String? _selectedMood;
  String? _selectedDuration;
  StartPointModel? _selectedStartPoint;
  final TextEditingController _customRegionController = TextEditingController();

  /// The fixed chips cover popular walkable neighborhoods, but the backend
  /// geocodes whatever string it's given -- so a typed region works just as
  /// well and isn't limited to the list.
  String? get _effectiveRegion {
    final typed = _customRegionController.text.trim();
    if (typed.isNotEmpty) return typed;
    return _selectedRegion;
  }

  @override
  void dispose() {
    _customRegionController.dispose();
    super.dispose();
  }

  Future<void> _onGeneratePressed(BuildContext context) async {
    final region = _effectiveRegion;
    if (region == null) return;

    final provider = context.read<WalkingCourseProvider>();
    await provider.generate(
      region,
      mood: _selectedMood,
      walkDuration: _selectedDuration,
      startPoint: _selectedStartPoint,
    );

    if (!context.mounted) return;
    Navigator.pushNamed(context, AppRoutes.walkingCourseResult);
  }

  Future<void> _pickStartPoint(BuildContext context) async {
    final picked = await Navigator.pushNamed<Object?>(
      context,
      AppRoutes.startPointPicker,
    );
    if (picked is StartPointModel && mounted) {
      setState(() => _selectedStartPoint = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<WalkingCourseProvider>().isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const Text(
                    '뚜벅이 코스',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: ResponsiveCenter(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '어디를 걸어볼까요?',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '지역과 분위기를 고르면 도보 코스를 짜드려요',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      const Text(
                        '지역',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final region in _walkingCourseRegions)
                            ChoiceChip(
                              key: Key('walkingCourseRegion_$region'),
                              label: Text(region),
                              selected: _selectedRegion == region,
                              onSelected: (_) => setState(() {
                                _selectedRegion = region;
                                // A chip pick replaces whatever was typed,
                                // so there's only ever one active region.
                                _customRegionController.clear();
                              }),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceTint3,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _selectedRegion == region
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedRegion == region
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('walkingCourseCustomRegionField'),
                        controller: _customRegionController,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) => setState(() {
                          // Typing takes over from a chip, so the two can't
                          // disagree about which region will be used.
                          if (value.trim().isNotEmpty) _selectedRegion = null;
                        }),
                        decoration: const InputDecoration(
                          hintText: '또는 원하는 지역 직접 입력 (예: 통영 강구안)',
                          prefixIcon: Icon(Icons.edit_location_alt_outlined),
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '분위기',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final mood in _walkingCourseMoods)
                            ChoiceChip(
                              label: Text(mood),
                              selected: _selectedMood == mood,
                              onSelected: (_) => setState(
                                () => _selectedMood = _selectedMood == mood
                                    ? null
                                    : mood,
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceTint3,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _selectedMood == mood
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedMood == mood
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '걷는 시간',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final duration in _walkingCourseDurations)
                            ChoiceChip(
                              label: Text(duration),
                              selected: _selectedDuration == duration,
                              onSelected: (_) => setState(
                                () => _selectedDuration =
                                    _selectedDuration == duration
                                    ? null
                                    : duration,
                              ),
                              selectedColor: AppColors.primary,
                              backgroundColor: AppColors.surfaceTint3,
                              side: BorderSide.none,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              labelStyle: TextStyle(
                                fontSize: 13.5,
                                fontWeight: _selectedDuration == duration
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                                color: _selectedDuration == duration
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        '시작 지점 (선택)',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _StartPointTile(
                        startPoint: _selectedStartPoint,
                        onTap: () => _pickStartPoint(context),
                        onClear: _selectedStartPoint == null
                            ? null
                            : () => setState(() => _selectedStartPoint = null),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        key: const Key('generateCourseButton'),
                        label: '코스 만들기',
                        isLoading: isLoading,
                        onPressed: _effectiveRegion != null
                            ? () => _onGeneratePressed(context)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the chosen start/end point for the course, or a prompt to pick
/// one. Optional by design -- without one the course is anchored on the
/// region's center point (FR-17 cold start).
class _StartPointTile extends StatelessWidget {
  const _StartPointTile({
    required this.startPoint,
    required this.onTap,
    required this.onClear,
  });

  final StartPointModel? startPoint;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final selected = startPoint;
    return InkWell(
      key: const Key('walkingCourseStartPointPicker'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint3,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Icon(
              selected == null
                  ? Icons.add_location_alt_outlined
                  : Icons.hotel_rounded,
              size: 18,
              color: selected == null
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected?.name ?? '시작 지점을 정하면 그곳에서 출발해 돌아오는 코스로 만들어요',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected == null
                      ? FontWeight.w500
                      : FontWeight.w700,
                  color: selected == null
                      ? AppColors.textSecondary
                      : AppColors.ink,
                ),
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                tooltip: '시작 지점 해제',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
