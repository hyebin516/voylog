import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/bookmark_provider.dart';
import '../repositories/bookmark_folder_repository.dart';
import 'dashed_border_container.dart';
import 'nav_icons.dart';

/// Shows the design's "북마크에 저장" bottom sheet: pick which folders the
/// given [bookmarkId] belongs to. Each row toggle saves immediately.
Future<void> showBookmarkFolderSheet(
  BuildContext context, {
  required String bookmarkId,
  String? placeId,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => BookmarkFolderSheet(bookmarkId: bookmarkId, placeId: placeId),
  );
}

class BookmarkFolderSheet extends StatefulWidget {
  const BookmarkFolderSheet({super.key, required this.bookmarkId, this.placeId});

  final String bookmarkId;

  /// The place this bookmark points at. Given, the sheet can unsave it
  /// outright -- the only way back out, since the bookmark icon now opens
  /// this sheet instead of toggling. Omitted, that action is hidden.
  final String? placeId;

  @override
  State<BookmarkFolderSheet> createState() => _BookmarkFolderSheetState();
}

class _BookmarkFolderSheetState extends State<BookmarkFolderSheet> {
  final _repository = BookmarkFolderRepository();
  final _nameController = TextEditingController();

  bool _loadingMembership = true;
  bool _creatingFolder = false;
  bool _removingBookmark = false;
  bool _showNewFolderField = false;
  final Set<String> _memberFolderIds = {};
  final Map<String, int> _displayCounts = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final folderProvider = context.read<BookmarkFolderProvider>();
    await folderProvider.loadFolders();
    if (!mounted) return;

    final folders = folderProvider.folders;
    final memberships = await Future.wait(
      folders.map((f) => _repository.listBookmarksInFolder(f.folderId)),
    );
    if (!mounted) return;

    setState(() {
      for (var i = 0; i < folders.length; i++) {
        _displayCounts[folders[i].folderId] = memberships[i].length;
        if (memberships[i].any((b) => b.bookmarkId == widget.bookmarkId)) {
          _memberFolderIds.add(folders[i].folderId);
        }
      }
      _loadingMembership = false;
    });
  }

  Future<void> _toggleFolder(String folderId) async {
    final isMember = _memberFolderIds.contains(folderId);
    setState(() {
      if (isMember) {
        _memberFolderIds.remove(folderId);
        _displayCounts[folderId] = (_displayCounts[folderId] ?? 1) - 1;
      } else {
        _memberFolderIds.add(folderId);
        _displayCounts[folderId] = (_displayCounts[folderId] ?? 0) + 1;
      }
    });

    try {
      if (isMember) {
        await _repository.removeBookmarkFromFolder(folderId, widget.bookmarkId);
      } else {
        await _repository.addBookmarkToFolder(folderId, widget.bookmarkId);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (isMember) {
          _memberFolderIds.add(folderId);
          _displayCounts[folderId] = (_displayCounts[folderId] ?? 0) + 1;
        } else {
          _memberFolderIds.remove(folderId);
          _displayCounts[folderId] = (_displayCounts[folderId] ?? 1) - 1;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더에 저장하지 못했어요.')));
    }
  }

  Future<void> _createFolder() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _creatingFolder = true);
    final folder = await context.read<BookmarkFolderProvider>().createFolder(name);
    if (!mounted) return;
    setState(() => _creatingFolder = false);

    if (folder == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('폴더를 만들지 못했어요.')));
      return;
    }

    _nameController.clear();
    setState(() {
      _showNewFolderField = false;
      _displayCounts[folder.folderId] = 0;
    });
    await _toggleFolder(folder.folderId);
  }

  Future<void> _removeBookmark() async {
    final placeId = widget.placeId;
    if (placeId == null) return;

    setState(() => _removingBookmark = true);
    final bookmarkProvider = context.read<BookmarkProvider>();
    await bookmarkProvider.removeBookmark(placeId);
    if (!mounted) return;

    final error = bookmarkProvider.errorMessage;
    if (error != null) {
      bookmarkProvider.clearError();
      setState(() => _removingBookmark = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    // The sheet is about a bookmark that no longer exists, so it goes too.
    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final folders = context.watch<BookmarkFolderProvider>().folders;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        boxShadow: AppColors.bottomSheetShadow(),
      ),
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 30),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(3)),
              ),
            ),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '북마크에 저장',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.surfaceTint2, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 16, color: AppColors.textTertiary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (_showNewFolderField)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(color: AppColors.surfaceTint1, borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: TextField(
                          controller: _nameController,
                          autofocus: true,
                          decoration: const InputDecoration(border: InputBorder.none, hintText: '폴더 이름을 입력하세요'),
                          onSubmitted: (_) => _createFolder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _creatingFolder ? null : _createFolder,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: _creatingFolder
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text(
                                '생성',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: DashedBorderContainer(
                  backgroundColor: AppColors.surfaceTint1,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  child: InkWell(
                    onTap: () => setState(() => _showNewFolderField = true),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.accentCyan, shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          '새 폴더 만들기',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primaryStrong),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            const Text(
              '내 폴더',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 230),
              child: _loadingMembership
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : folders.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text('아직 만든 폴더가 없어요.', style: TextStyle(color: AppColors.textMuted)),
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              for (final folder in folders)
                                _FolderRow(
                                  name: folder.name,
                                  count: _displayCounts[folder.folderId] ?? folder.bookmarkCount,
                                  selected: _memberFolderIds.contains(folder.folderId),
                                  onTap: () => _toggleFolder(folder.folderId),
                                ),
                            ],
                          ),
                        ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.placeId != null)
                  InkWell(
                    onTap: _removingBookmark ? null : _removeBookmark,
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
                      child: Text(
                        _removingBookmark ? '해제 중…' : '북마크 해제',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.of(context).maybePop(),
                  borderRadius: BorderRadius.circular(999),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    child: const Text(
                      '저장하기',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  const _FolderRow({required this.name, required this.count, required this.selected, required this.onTap});

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceTint3 : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? Colors.white : AppColors.surfaceTint2,
                borderRadius: BorderRadius.circular(12),
              ),
              child: FolderGlyphIcon(
                size: 17,
                color: selected ? AppColors.primary : AppColors.textMuted,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text('장소 $count곳', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : null,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: AppColors.dividerStrong, width: 2),
              ),
              child: selected ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }
}
