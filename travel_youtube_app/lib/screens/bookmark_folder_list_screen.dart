import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/bookmark_folder_model.dart';
import '../providers/bookmark_folder_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/loading_indicator.dart';
import '../widgets/saved_routes_fab.dart';

class BookmarkFolderListScreen extends StatefulWidget {
  /// When true, this renders as the bottom nav's "북마크" tab root (design's
  /// `isBookmarkFolders` screen): no back button, "북마크" title, and the
  /// floating "내 여행" shortcut. When false (the default), it renders as a
  /// screen pushed on top of something else (e.g. from 내 페이지): back
  /// button, "북마크 폴더" title, no FAB.
  final bool isTabRoot;

  const BookmarkFolderListScreen({super.key, this.isTabRoot = false});

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
      backgroundColor: Colors.white,
      floatingActionButton: widget.isTabRoot
          ? SavedRoutesFab(onPressed: () => Navigator.pushNamed(context, AppRoutes.savedWalkingCourses))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  if (!widget.isTabRoot) ...[
                    _RoundIconButton(
                      icon: Icons.arrow_back_ios_new_rounded,
                      onTap: () => Navigator.of(context).maybePop(),
                      bg: AppColors.surfaceTint2,
                      iconColor: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Text(
                      widget.isTabRoot ? '북마크' : '북마크 폴더',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ),
                  _RoundIconButton(
                    icon: Icons.add_rounded,
                    onTap: _createFolder,
                    gradient: true,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Builder(
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
                    return const Center(child: Text('아직 만든 폴더가 없습니다.', style: TextStyle(color: AppColors.textMuted)));
                  }

                  return ListView.separated(
                    // The FAB (only shown when isTabRoot) is fixed on screen
                    // and doesn't scroll with this list -- 20dp of bottom
                    // padding isn't enough clearance for its ~72dp footprint
                    // (56dp button + 16dp margin), so the last folder card
                    // can end up right underneath it once the list is long
                    // enough to scroll, and a tap meant for that card would
                    // hit the FAB instead (see the identical fix on
                    // home_screen.dart's shared-route section).
                    padding: EdgeInsets.fromLTRB(20, 4, 20, widget.isTabRoot ? 190 : 20),
                    itemCount: folderProvider.folders.length,
                    separatorBuilder: (context, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final folder = folderProvider.folders[index];
                      return _FolderCard(
                        folder: folder,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.bookmarkFolderDetail, arguments: folder.folderId),
                        onDelete: () => _confirmDeleteFolder(folder),
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

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap, this.bg, this.iconColor, this.gradient = false});

  final IconData icon;
  final VoidCallback onTap;
  final Color? bg;
  final Color? iconColor;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: gradient ? null : bg,
          gradient: gradient ? const LinearGradient(colors: [AppColors.accentCyan, AppColors.primaryStrong]) : null,
          borderRadius: BorderRadius.circular(12),
          boxShadow: gradient
              ? [BoxShadow(color: AppColors.primaryStrong.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))]
              : null,
        ),
        child: Icon(icon, size: 17, color: gradient ? Colors.white : iconColor),
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.onTap, required this.onDelete});

  final BookmarkFolderModel folder;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppColors.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: AppColors.surfaceTint3, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.folder_outlined, size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(folder.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('장소 ${folder.bookmarkCount}곳', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            _RoundIconButton(
              icon: Icons.delete_outline_rounded,
              onTap: onDelete,
              bg: const Color(0xFFFDF1F0),
              iconColor: AppColors.danger,
            ),
          ],
        ),
      ),
    );
  }
}
