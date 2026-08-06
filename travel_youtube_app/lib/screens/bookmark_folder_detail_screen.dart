import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

class BookmarkFolderDetailScreen extends StatefulWidget {
  final String folderId;

  const BookmarkFolderDetailScreen({super.key, required this.folderId});

  @override
  State<BookmarkFolderDetailScreen> createState() => _BookmarkFolderDetailScreenState();
}

class _BookmarkFolderDetailScreenState extends State<BookmarkFolderDetailScreen> {
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
    Navigator.pushNamed(context, AppRoutes.bookmarkFolderPicker, arguments: widget.folderId);
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<BookmarkFolderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('폴더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '북마크 추가',
            onPressed: _openPicker,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (folderProvider.isDetailLoading && folderProvider.folderBookmarks.isEmpty) {
            return const LoadingIndicator();
          }
          if (folderProvider.detailState == ViewState.error && folderProvider.folderBookmarks.isEmpty) {
            return ErrorView(
              message: folderProvider.detailErrorMessage ?? '폴더를 불러오지 못했습니다.',
              onRetry: () => folderProvider.loadFolderBookmarks(widget.folderId),
            );
          }
          if (folderProvider.folderBookmarks.isEmpty) {
            return const Center(child: Text('이 폴더에 담긴 북마크가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: folderProvider.folderBookmarks.length,
            separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final BookmarkModel bookmark = folderProvider.folderBookmarks[index];
              return Card(
                child: ListTile(
                  title: Text(bookmark.name),
                  subtitle: bookmark.address != null ? Text(bookmark.address!) : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '폴더에서 제거',
                    onPressed: () => folderProvider.toggleBookmarkInFolder(widget.folderId, bookmark.bookmarkId),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
