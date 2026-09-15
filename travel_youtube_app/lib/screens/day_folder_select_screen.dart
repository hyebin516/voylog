import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_folder_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/itinerary_provider.dart';
import '../providers/trip_provider.dart';
import '../repositories/bookmark_folder_repository.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/nav_icons.dart';

/// "N일차 북마크 선택" -- the design's `isDayPlaceSelect` screen, reached from
/// [TripDetailScreen]'s "N일차 추가"/"날짜 추가". Picks ONE bookmark folder
/// (not individual places) to seed the day's route with; places can still
/// be dropped on the next screen, matching "폴더를 고르면 그 안의 장소로
/// 동선을 짜드려요 ... 다음 단계에서 장소를 더 줄일 수 있어요".
class DayFolderSelectScreen extends StatefulWidget {
  const DayFolderSelectScreen({super.key});

  @override
  State<DayFolderSelectScreen> createState() => _DayFolderSelectScreenState();
}

class _DayFolderSelectScreenState extends State<DayFolderSelectScreen> {
  final _folderRepository = BookmarkFolderRepository();
  String? _selectedFolderId;
  bool _loadingPlaces = false;

  @override
  void initState() {
    super.initState();
    _selectedFolderId = context.read<TripProvider>().takePendingFolderId();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkFolderProvider>().loadFolders();
    });
  }

  Future<void> _next() async {
    final folderId = _selectedFolderId;
    if (folderId == null || _loadingPlaces) return;

    final folder = context
        .read<BookmarkFolderProvider>()
        .folders
        .where((f) => f.folderId == folderId)
        .firstOrNull;
    if (folder == null) return;

    setState(() => _loadingPlaces = true);
    try {
      final places = await _folderRepository.listBookmarksInFolder(folderId);
      if (!mounted) return;
      context.read<ItineraryProvider>().setSelectedPlacesFromFolder(
        folderId,
        folder.name,
        places,
      );
      Navigator.pushNamed(context, AppRoutes.routePlanner);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('폴더의 장소를 불러오지 못했어요.')));
      }
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<BookmarkFolderProvider>();
    final tripProvider = context.watch<TripProvider>();
    final dayLabel =
        '${tripProvider.activeDayNumber ?? tripProvider.nextDayNumber}일차';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
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
                  Text(
                    '$dayLabel 북마크 선택',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '어느 북마크를 쓸까요?',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '폴더를 고르면 그 안의 장소로 동선을 짜드려요',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (folderProvider.isLoading &&
                      folderProvider.folders.isEmpty) {
                    return const LoadingIndicator();
                  }
                  if (folderProvider.state == ViewState.error &&
                      folderProvider.folders.isEmpty) {
                    return ErrorView(
                      message:
                          folderProvider.errorMessage ?? '폴더 목록을 불러오지 못했습니다.',
                      onRetry: () => folderProvider.loadFolders(),
                    );
                  }
                  if (folderProvider.folders.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          '아직 만든 북마크 폴더가 없어요.\n북마크 탭에서 폴더를 먼저 만들어 주세요.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      for (final folder in folderProvider.folders) ...[
                        _FolderOption(
                          folder: folder,
                          selected: folder.folderId == _selectedFolderId,
                          onTap: () => setState(
                            () => _selectedFolderId = folder.folderId,
                          ),
                        ),
                        const SizedBox(height: 11),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceTint1,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 14,
                              color: Color(0xFF8BB9CF),
                            ),
                            SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                '동선은 한 번에 2~10곳까지 최적화할 수 있어요. 다음 단계에서 장소를 더 줄일 수 있어요.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  height: 1.55,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: (_selectedFolderId != null && !_loadingPlaces)
                      ? _next
                      : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: const StadiumBorder(),
                  ),
                  child: _loadingPlaces
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          '다음 · 호텔 선택',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
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

class _FolderOption extends StatelessWidget {
  const _FolderOption({
    required this.folder,
    required this.selected,
    required this.onTap,
  });

  final BookmarkFolderModel folder;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceTint3 : AppColors.surfaceTint1,
          border: Border.all(
            color: selected ? AppColors.selectedBorder : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: FolderGlyphIcon(
                size: 22,
                color: selected ? AppColors.primary : const Color(0xFF8BB9CF),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    folder.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '장소 ${folder.bookmarkCount}곳',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.textTertiary
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDCEAF1), width: 2),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
