import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/bookmark_provider.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

/// Lets the user tag any of their bookmarks into the folder identified by
/// [folderId]. A bookmark can belong to multiple folders at once, so this
/// is a simple checked/unchecked toggle rather than a single-choice move.
class BookmarkFolderPickerScreen extends StatefulWidget {
  final String folderId;

  const BookmarkFolderPickerScreen({super.key, required this.folderId});

  @override
  State<BookmarkFolderPickerScreen> createState() => _BookmarkFolderPickerScreenState();
}

class _BookmarkFolderPickerScreenState extends State<BookmarkFolderPickerScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkProvider>().loadBookmarks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookmarkProvider = context.watch<BookmarkProvider>();
    final folderProvider = context.watch<BookmarkFolderProvider>();

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
                      decoration: BoxDecoration(color: AppColors.surfaceTint2, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new_rounded, size: 17, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('폴더에 추가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: Builder(
                builder: (context) {
                  if (bookmarkProvider.isLoading && bookmarkProvider.bookmarks.isEmpty) {
                    return const LoadingIndicator();
                  }
                  if (bookmarkProvider.state == ViewState.error && bookmarkProvider.bookmarks.isEmpty) {
                    return ErrorView(
                      message: bookmarkProvider.errorMessage ?? '북마크를 불러오지 못했습니다.',
                      onRetry: () => bookmarkProvider.loadBookmarks(),
                    );
                  }
                  if (bookmarkProvider.bookmarks.isEmpty) {
                    return const Center(child: Text('북마크한 장소가 없습니다.', style: TextStyle(color: AppColors.textMuted)));
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                    itemCount: bookmarkProvider.bookmarks.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final BookmarkModel bookmark = bookmarkProvider.bookmarks[index];
                      // Material, not a colored Container: the tile paints its
                      // tap ripple on the nearest Material, which a colored
                      // Container would hide.
                      return Material(
                        color: AppColors.surfaceTint1,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                          side: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: CheckboxListTile(
                          title: Text(bookmark.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          subtitle: bookmark.address != null
                              ? Text(bookmark.address!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted))
                              : null,
                          value: folderProvider.isInCurrentFolder(bookmark.bookmarkId),
                          onChanged: (_) => folderProvider.toggleBookmarkInFolder(widget.folderId, bookmark.bookmarkId),
                          activeColor: AppColors.primary,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
