import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_folder_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/app_card.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';

class BookmarkFolderListScreen extends StatefulWidget {
  const BookmarkFolderListScreen({super.key});

  @override
  State<BookmarkFolderListScreen> createState() => _BookmarkFolderListScreenState();
}

class _BookmarkFolderListScreenState extends State<BookmarkFolderListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookmarkFolderProvider>().loadFolders();
    });
  }

  Future<void> _createFolder() async {
    final nameController = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('새 폴더 만들기'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(hintText: '예: 제주 맛집'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, nameController.text.trim()),
            child: const Text('만들기'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final folderProvider = context.read<BookmarkFolderProvider>();
    final folder = await folderProvider.createFolder(name);
    if (!mounted) return;

    if (folder != null) {
      Navigator.pushNamed(context, AppRoutes.bookmarkFolderDetail, arguments: folder.folderId);
    } else {
      final message = folderProvider.errorMessage ?? '폴더 생성에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  Future<void> _confirmDeleteFolder(BookmarkFolderModel folder) async {
    final folderProvider = context.read<BookmarkFolderProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('폴더 삭제'),
        content: Text('${folder.name} 폴더를 삭제하시겠습니까? 담긴 북마크 자체는 삭제되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('삭제')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final success = await folderProvider.deleteFolder(folder.folderId);
    if (!success && mounted) {
      final message = folderProvider.errorMessage ?? '폴더 삭제에 실패했습니다.';
      showErrorDialog(context, message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final folderProvider = context.watch<BookmarkFolderProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('북마크 폴더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: '새 폴더 만들기',
            onPressed: _createFolder,
          ),
        ],
      ),
      body: Builder(
        builder: (context) {
          if (folderProvider.isLoading && folderProvider.folders.isEmpty) {
            return const LoadingIndicator();
          }
          if (folderProvider.state == ViewState.error && folderProvider.folders.isEmpty) {
            return ErrorView(
              message: folderProvider.errorMessage ?? '폴더 목록을 불러오지 못했습니다.',
              onRetry: () => folderProvider.loadFolders(),
            );
          }
          if (folderProvider.folders.isEmpty) {
            return const Center(child: Text('아직 만든 폴더가 없습니다.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: folderProvider.folders.length,
            separatorBuilder: (context, _) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final folder = folderProvider.folders[index];
              return AppCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                onTap: () => Navigator.pushNamed(context, AppRoutes.bookmarkFolderDetail, arguments: folder.folderId),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(folder.name, style: Theme.of(context).textTheme.titleMedium),
                          Text('${folder.bookmarkCount}개 저장됨', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      tooltip: '폴더 삭제',
                      onPressed: () => _confirmDeleteFolder(folder),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
