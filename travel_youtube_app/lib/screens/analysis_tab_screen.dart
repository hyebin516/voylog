import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../providers/video_provider.dart';
import '../routes/app_routes.dart';
import '../utils/view_state.dart';
import '../widgets/error_view.dart';
import '../widgets/nav_icons.dart';
import '../widgets/responsive_center.dart';

/// Landing content for the bottom nav's "분석" tab. The design handoff's
/// navigation model lists this as its own tab without specifying separate
/// content for it, so this mirrors the URL-analyze entry point (the same
/// action Home's hero section offers) as a focused, always-reachable tab.
class AnalysisTabScreen extends StatefulWidget {
  const AnalysisTabScreen({super.key});

  @override
  State<AnalysisTabScreen> createState() => _AnalysisTabScreenState();
}

class _AnalysisTabScreenState extends State<AnalysisTabScreen> {
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveCenter(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('분석', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
                const SizedBox(height: 22),
                const Text(
                  '브이로그로 동선을 만들어드려요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
                ),
                const SizedBox(height: 6),
                const Text(
                  '여행 브이로그 URL을 붙여넣으면 AI가 자동으로 동선을 만들어줘요',
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFD9EDF7), width: 2),
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: AppColors.cardShadow(),
                  ),
                  child: Row(
                    children: [
                      const LinkGlyphIcon(size: 17, color: AppColors.textTertiary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const Key('analysisTabUrlField'),
                          controller: _urlController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            hintText: '브이로그 URL을 붙여넣으세요',
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
                        ),
                      ),
                      InkWell(
                        onTap: videoProvider.isLoading ? null : () => _onAnalyzePressed(videoProvider),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [AppColors.accentCyan, AppColors.primaryStrong]),
                            shape: BoxShape.circle,
                          ),
                          child: videoProvider.isLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                                )
                              : const Icon(Icons.arrow_forward_rounded, size: 18, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_inputError != null) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 20),
                    child: Text(_inputError!, style: const TextStyle(fontSize: 12, color: AppColors.danger)),
                  ),
                ],
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
      ),
    );
  }
}
