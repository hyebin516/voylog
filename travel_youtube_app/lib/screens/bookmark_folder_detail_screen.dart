import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/walking_course_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/dashed_border_container.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/nav_icons.dart';
import '../widgets/primary_button.dart';

class BookmarkFolderDetailScreen extends StatefulWidget {
  final String folderId;

  const BookmarkFolderDetailScreen({super.key, required this.folderId});

  @override
  State<BookmarkFolderDetailScreen> createState() =>
      _BookmarkFolderDetailScreenState();
}

class _BookmarkFolderDetailScreenState
    extends State<BookmarkFolderDetailScreen> {
  late final BookmarkFolderProvider _folderProvider;

  @override
  void initState() {
    super.initState();
    _folderProvider = context.read<BookmarkFolderProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _folderProvider.loadFolderBookmarks(widget.folderId);
    });
  }

  @override
  void dispose() {
    _folderProvider.clearFolderDetail();
    super.dispose();
  }

  void _openPicker() {
    Navigator.pushNamed(
      context,
      AppRoutes.bookmarkFolderPicker,
      arguments: widget.folderId,
    );
  }

  /// Routes the folder's places right here -- no hotel, no trip, the way
  /// a 뚜벅이 코스 is generated. Sending the user to the 여행 tab to pick a
  /// trip, a day and two hotels first meant the button never actually made
  /// a route; saving it to a trip stays available from the result screen.
  Future<void> _startRouteFromFolder(String folderName) async {
    final courseProvider = context.read<WalkingCourseProvider>();
    await courseProvider.generateFromBookmarkFolder(
      folderId: widget.folderId,
      folderName: folderName,
    );
    if (!mounted) return;

    if (courseProvider.state == ViewState.error) {
      await showErrorDialog(context, courseProvider.errorMessage ?? '동선을 만들지 못했습니다.');
      return;
    }
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.walkingCourseResult);
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<BookmarkFolderProvider>();
    final folderName = folderProvider.folders
        .where((f) => f.folderId == widget.folderId)
        .map((f) => f.name)
        .firstOrNull;

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
                  Expanded(
                    child: Text(
                      folderName ?? '폴더',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${folderProvider.folderBookmarks.length}개 저장됨',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (folderProvider.isDetailLoading &&
                      folderProvider.folderBookmarks.isEmpty) {
                    return const LoadingIndicator();
                  }
                  if (folderProvider.detailState == ViewState.error &&
                      folderProvider.folderBookmarks.isEmpty) {
                    return ErrorView(
                      message:
                          folderProvider.detailErrorMessage ??
                          '폴더를 불러오지 못했습니다.',
                      onRetry: () =>
                          folderProvider.loadFolderBookmarks(widget.folderId),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    children: [
                      GestureDetector(
                        onTap: _openPicker,
                        child: DashedBorderContainer(
                          backgroundColor: AppColors.surfaceTint1,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                alignment: Alignment.center,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentCyan,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_rounded,
                                  size: 15,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                '장소 추가하기',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryStrong,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (folderProvider.folderBookmarks.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: Center(
                            child: Text(
                              '이 폴더에 담긴 북마크가 없습니다.',
                              style: TextStyle(color: AppColors.textMuted),
                            ),
                          ),
                        )
                      else
                        for (final bookmark
                            in folderProvider.folderBookmarks) ...[
                          _BookmarkRow(
                            bookmark: bookmark,
                            onRemove: () =>
                                folderProvider.toggleBookmarkInFolder(
                                  widget.folderId,
                                  bookmark.bookmarkId,
                                ),
                          ),
                          const SizedBox(height: 10),
                        ],
                    ],
                  );
                },
              ),
            ),
            // Matches the design's `isFolderDetail` footer -- fixed white
            // bar with an upward shadow, full-width primary button.
            Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 24,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: PrimaryButton(
                label: 'AI 동선 생성하기',
                iconWidget: const SparkleGlyphIcon(size: 15, color: Colors.white),
                isLoading: context.watch<WalkingCourseProvider>().isLoading,
                onPressed: folderProvider.folderBookmarks.length >= 2
                    ? () => _startRouteFromFolder(folderName ?? '내 북마크')
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarkRow extends StatelessWidget {
  const _BookmarkRow({required this.bookmark, required this.onRemove});

  final BookmarkModel bookmark;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint1,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceTint3,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.place_outlined,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (bookmark.address != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    bookmark.address!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 15,
                color: AppColors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
