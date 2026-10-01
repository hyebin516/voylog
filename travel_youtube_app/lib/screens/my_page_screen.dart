import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/bookmark_folder_provider.dart';
import '../providers/trip_provider.dart';
import '../routes/app_routes.dart';
import '../services/image_picker_service.dart';
import '../widgets/auth_backdrop.dart';
import '../widgets/profile_avatar.dart';

class MyPageScreen extends StatefulWidget {
  /// Injectable so widget tests can pick a photo without the gallery.
  const MyPageScreen({super.key, this.imagePicker = const GalleryImagePickerService()});

  final ImagePickerService imagePicker;

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadTrips();
      context.read<BookmarkFolderProvider>().loadFolders();
    });
  }

  Future<void> _confirmLogout() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.logout_rounded,
      title: '로그아웃할까요?',
      message: '저장한 북마크와 여행 일정은 다시 로그인하면 그대로 있어요',
    );
    if (confirmed != true || !mounted) return;

    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  Future<void> _confirmWithdraw() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.person_remove_outlined,
      title: '정말 탈퇴할까요?',
      message: '저장한 동선과 북마크가 모두 삭제되며 복구할 수 없어요',
    );
    if (confirmed != true || !mounted) return;

    final success = await context.read<AuthProvider>().deleteAccount();
    if (!mounted) return;
    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
    } else {
      final message = context.read<AuthProvider>().errorMessage ?? '회원 탈퇴에 실패했습니다.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<bool?> _showConfirmDialog({required IconData icon, required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: Color(0xFFFDF1F0), shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: AppColors.danger),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary, height: 1.6),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: AppColors.surfaceTint2,
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide.none,
                        ),
                        child: const Text('취소'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, elevation: 0),
                        child: const Text('확인'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A Kakao account only has an email if the user consented to sharing it,
  /// so a logged-in Kakao user often has none -- showing the logged-out
  /// "비회원으로 둘러보는 중" line for them said they weren't a member at all.
  static String _accountSubtitle(UserModel? user) {
    if (user == null) return '비회원으로 둘러보는 중';
    if (user.email != null && user.email!.isNotEmpty) return user.email!;
    return user.isKakaoAccount ? '카카오 계정으로 로그인' : '로그인 중';
  }

  Future<void> _openPhotoSheet() async {
    final hasPhoto = context.read<AuthProvider>().currentUser?.profileImage != null;

    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      barrierColor: AppColors.overlay,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 12),
            ListTile(
              key: const Key('pickPhotoTile'),
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary),
              title: const Text('앨범에서 선택', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink)),
              onTap: () => Navigator.of(sheetContext).pop('pick'),
            ),
            if (hasPhoto)
              ListTile(
                key: const Key('removePhotoTile'),
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('기본 이미지로 변경', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.danger)),
                onTap: () => Navigator.of(sheetContext).pop('remove'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'pick') {
      await _pickAndUploadPhoto();
    } else {
      await _applyPhotoChange(() => context.read<AuthProvider>().removeProfileImage(), '기본 이미지로 바꿨어요.');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    final path = await widget.imagePicker.pickFromGallery();
    // Null means the user closed the gallery without choosing -- not a failure.
    if (path == null || !mounted) return;
    await _applyPhotoChange(() => context.read<AuthProvider>().updateProfileImage(path), '프로필 사진을 바꿨어요.');
  }

  Future<void> _applyPhotoChange(Future<bool> Function() change, String successMessage) async {
    setState(() => _savingPhoto = true);
    final ok = await change();
    if (!mounted) return;
    setState(() => _savingPhoto = false);

    final provider = context.read<AuthProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? successMessage : provider.errorMessage ?? '프로필 사진을 바꾸지 못했어요.')),
    );
  }

  Future<void> _openEditNickname(String currentNickname) async {
    final controller = TextEditingController(text: currentNickname);
    final newNickname = await showDialog<String>(
      context: context,
      barrierColor: AppColors.overlay,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 30),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(imageUrl: context.read<AuthProvider>().currentUser?.profileImage, size: 64),
              const SizedBox(height: 14),
              const Text('프로필 수정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 14),
              TextField(controller: controller, decoration: const InputDecoration(hintText: '닉네임 입력')),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(controller.text),
                      child: const Text('저장'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (newNickname == null || newNickname.trim().isEmpty || !mounted) return;
    if (newNickname.trim() == currentNickname) return;

    final ok = await context.read<AuthProvider>().updateNickname(newNickname.trim());
    if (!mounted) return;

    final message = ok
        ? '닉네임을 변경했어요.'
        : (context.read<AuthProvider>().errorMessage ?? '닉네임 변경에 실패했습니다.');
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;
    final tripCount = context.watch<TripProvider>().trips.length;
    final folderCount = context.watch<BookmarkFolderProvider>().folders.length;

    return Scaffold(
      body: AuthBackdrop(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('내 페이지', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        // Guests have no profile to change.
                        if (user == null)
                          const ProfileAvatar(imageUrl: null, shadow: true)
                        else
                          Semantics(
                            button: true,
                            label: '프로필 사진 변경',
                            child: InkWell(
                              key: const Key('profileAvatarButton'),
                              onTap: _openPhotoSheet,
                              customBorder: const CircleBorder(),
                              child: Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  ProfileAvatar(imageUrl: user.profileImage, shadow: true),
                                  if (_savingPhoto)
                                    const Positioned.fill(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(color: AppColors.overlay, shape: BoxShape.circle),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: AppColors.divider),
                                    ),
                                    child: const Icon(Icons.photo_camera_rounded, size: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.nickname ?? '게스트',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _accountSubtitle(user),
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (user != null)
                          OutlinedButton(
                            onPressed: () => _openEditNickname(user.nickname),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textSecondary,
                              side: BorderSide.none,
                              minimumSize: const Size(0, 0),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                            ),
                            child: const Text('수정'),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: _StatTile(
                            count: tripCount,
                            label: '내 여행',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.tripList),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _StatTile(
                            count: folderCount,
                            label: '북마크 폴더',
                            onTap: () => Navigator.pushNamed(context, AppRoutes.bookmarkFolders),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
                  children: [
                    _MenuTile(
                      icon: Icons.badge_outlined,
                      label: '계정 설정',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MenuTile(
                      icon: Icons.favorite_border_rounded,
                      label: '취향 설정',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.tastePreferences),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MenuTile(
                      icon: Icons.people_alt_outlined,
                      label: '취향 맞춤 추천',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.similarTasteRecommendations),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MenuTile(
                      icon: Icons.notifications_outlined,
                      label: '알림 설정',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.notificationSettings),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _MenuTile(
                      icon: Icons.support_agent_outlined,
                      label: '고객센터',
                      onTap: () => Navigator.pushNamed(context, AppRoutes.customerService),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (user != null) ...[
                      _MenuTile(
                        icon: Icons.logout_rounded,
                        label: '로그아웃',
                        labelColor: AppColors.danger,
                        showChevron: false,
                        onTap: _confirmLogout,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _MenuTile(
                        icon: Icons.person_remove_outlined,
                        iconBg: const Color(0xFFFDF1F0),
                        label: '회원 탈퇴',
                        labelColor: AppColors.danger,
                        showChevron: false,
                        onTap: _confirmWithdraw,
                      ),
                    ] else
                      _MenuTile(
                        icon: Icons.login_rounded,
                        iconBg: AppColors.surfaceTint3,
                        label: '로그인하기',
                        labelColor: AppColors.primaryStrong,
                        showChevron: false,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.login),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.count, required this.label, required this.onTap});

  final int count;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.dividerStrong, width: 1.5),
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.cardShadow(),
        ),
        child: Column(
          children: [
            Text('$count', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconBg = AppColors.surfaceTint3,
    this.labelColor = AppColors.ink,
    this.showChevron = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color iconBg;
  final Color labelColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.dividerStrong, width: 1.5),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 16, color: labelColor == AppColors.danger ? AppColors.danger : AppColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: labelColor)),
            ),
            if (showChevron) const Icon(Icons.chevron_right_rounded, size: 15, color: AppColors.borderStrong),
          ],
        ),
      ),
    );
  }
}
