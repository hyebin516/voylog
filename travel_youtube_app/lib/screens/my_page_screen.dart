import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../routes/app_routes.dart';
import '../widgets/app_card.dart';

class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  Future<void> _onLogout(BuildContext context) async {
    await context.read<AuthProvider>().logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, AppRoutes.login, (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          AppCard(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.surfaceTint,
                  backgroundImage: user?.profileImage != null ? NetworkImage(user!.profileImage!) : null,
                  child: user?.profileImage == null
                      ? const Icon(Icons.person_rounded, color: AppColors.primary)
                      : null,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.nickname ?? '게스트', style: Theme.of(context).textTheme.titleMedium),
                      if (user?.email != null) Text(user!.email!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MenuTile(
                  icon: Icons.bookmark_outline_rounded,
                  label: '북마크',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.bookmarks),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.folder_outlined,
                  label: '북마크 폴더',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.bookmarkFolders),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.card_travel_rounded,
                  label: '내 여행',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tripList),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.favorite_border_rounded,
                  label: '취향 설정',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.tastePreferences),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.people_alt_outlined,
                  label: '비슷한 취향 추천',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.similarTasteRecommendations),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.directions_walk_rounded,
                  label: '뚜벅이 코스',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.walkingCourseRegion),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.bookmark_added_outlined,
                  label: '내 코스 목록',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.savedWalkingCourses),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.support_agent_outlined,
                  label: '고객센터',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.customerService),
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                _MenuTile(
                  icon: Icons.settings_outlined,
                  label: '설정',
                  onTap: () => Navigator.pushNamed(context, AppRoutes.settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppColors.coral),
              title: const Text('로그아웃', style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w600)),
              onTap: () => _onLogout(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.primary),
      onTap: onTap,
    );
  }
}
