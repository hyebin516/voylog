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
      appBar: AppBar(title: const Text('폴더에 추가')),
      body: Builder(
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
            return const Center(child: Text('북마크한 장소가 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: bookmarkProvider.bookmarks.length,
            itemBuilder: (context, index) {
              final BookmarkModel bookmark = bookmarkProvider.bookmarks[index];
              return CheckboxListTile(
                title: Text(bookmark.name),
                subtitle: bookmark.address != null ? Text(bookmark.address!) : null,
                value: folderProvider.isInCurrentFolder(bookmark.bookmarkId),
                onChanged: (_) => folderProvider.toggleBookmarkInFolder(widget.folderId, bookmark.bookmarkId),
              );
            },
          );
        },
      ),
    );
  }
}
