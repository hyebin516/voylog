import 'package:flutter/material.dart';

import '../core/constants/customer_service_content.dart';
import '../core/theme/app_theme.dart';

class CustomerServiceScreen extends StatelessWidget {
  const CustomerServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('고객센터')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('자주 묻는 질문', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (final faq in CustomerServiceContent.faqs)
            Card(
              child: ExpansionTile(
                title: Text(faq.question),
                childrenPadding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(faq.answer)],
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Text('문의하기', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('이메일로 문의'),
              subtitle: const Text(CustomerServiceContent.contactEmail),
            ),
          ),
        ],
      ),
    );
  }
}
