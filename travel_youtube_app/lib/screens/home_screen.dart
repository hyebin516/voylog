import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/primary_button.dart';
import '../widgets/responsive_center.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  String? _inputError;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _onAnalyzePressed(VideoProvider videoProvider) async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() => _inputError = 'URL을 먼저 입력해 주세요.');
      return;
    }
    setState(() => _inputError = null);

    await videoProvider.analyze(url);

    if (!mounted) return;
    if (videoProvider.state == ViewState.success) {
      Navigator.pushNamed(context, AppRoutes.videoAnalysis);
    }
  }

  @override
  Widget build(BuildContext context) {
    final videoProvider = context.watch<VideoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('여행 유튜브 요약'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bookmark_outline_rounded),
            tooltip: '북마크',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.bookmarks),
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: '마이페이지',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.myPage),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: ResponsiveCenter(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '분석할 유튜브 영상 URL을 입력하세요',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  hintText: 'https://youtube.com/watch?v=...',
                  errorText: _inputError,
                  prefixIcon: const Icon(Icons.link_rounded),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: '분석하기',
                icon: Icons.auto_awesome_rounded,
                isLoading: videoProvider.isLoading,
                onPressed: () => _onAnalyzePressed(videoProvider),
              ),
              if (videoProvider.state == ViewState.error) ...[
                const SizedBox(height: AppSpacing.lg),
                ErrorView(
                  message: videoProvider.errorMessage ?? '분석에 실패했습니다.',
                  onRetry: () => _onAnalyzePressed(videoProvider),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
