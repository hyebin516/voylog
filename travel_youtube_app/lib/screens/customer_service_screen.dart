import 'package:flutter/material.dart';

import '../core/constants/customer_service_content.dart';
import '../core/theme/app_theme.dart';
import '../widgets/app_card.dart';

class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('자주 묻는 질문', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          for (final faq in CustomerServiceContent.faqs) ...[
            AppCard(
              padding: EdgeInsets.zero,
              child: ExpansionTile(
                title: Text(faq.question),
                iconColor: AppColors.primary,
                collapsedIconColor: AppColors.primary,
                childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(faq.answer)],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('문의하기', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.mail_outline_rounded, color: AppColors.primary),
              title: const Text('이메일로 문의'),
              subtitle: const Text(CustomerServiceContent.contactEmail),
            ),
          ),
        ],
      ),
    );
  }
}
