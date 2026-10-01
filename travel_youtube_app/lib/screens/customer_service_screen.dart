import 'package:flutter/material.dart';

import '../core/constants/customer_service_content.dart';
import '../core/constants/public_data_sources.dart';
import '../core/theme/app_theme.dart';
import '../routes/app_routes.dart';

class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
                  const Text('고객센터', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                children: [
                  const Text('자주 묻는 질문', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  for (final faq in CustomerServiceContent.faqs) ...[
                    // Material, not a colored Container, so the expansion
                    // tile's tap ripple isn't hidden under the background.
                    Material(
                      color: AppColors.surfaceTint1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: AppColors.surfaceTint3, borderRadius: BorderRadius.circular(8)),
                                child: const Text('Q', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(faq.question, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.ink)),
                              ),
                            ],
                          ),
                          iconColor: AppColors.textTertiary,
                          collapsedIconColor: AppColors.textTertiary,
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          expandedCrossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(color: const Color(0xFFEAFAF3), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF5FC2A0))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(faq.answer, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  const Text('문의하기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  // FR-13: the address alone was unusable from inside the
                  // app -- this opens the form that actually sends it.
                  Material(
                    color: AppColors.surfaceTint1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                      side: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      key: const Key('supportInquiryEntry'),
                      onTap: () => Navigator.of(context).pushNamed(AppRoutes.supportInquiry),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.mail_outline_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('문의 보내기', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                                  const SizedBox(height: 2),
                                  const Text(
                                    '앱에서 바로 문의하고 답변은 메일로 받아요',
                                    style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textTertiary),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '메일로 직접 보내셔도 됩니다 — ${CustomerServiceContent.contactEmail}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  const Text('데이터 출처', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceTint1,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.dividerStrong, width: 1.5),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final source in PublicDataSources.all) ...[
                          Text(source.provider, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.ink)),
                          const SizedBox(height: 2),
                          Text(source.dataset, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                          const SizedBox(height: 10),
                        ],
                        const Text(
                          '장소 정보 일부는 위 기관의 공공데이터를 ${PublicDataSources.license} 조건에 따라 이용했습니다.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
