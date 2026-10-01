import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/theme/app_theme.dart';
import '../models/support_inquiry_model.dart';
import '../providers/auth_provider.dart';
import '../providers/support_inquiry_provider.dart';
import '../widgets/primary_button.dart';

/// FR-13 문의하기. The customer service screen used to show a support
/// address and nothing else; this sends the question from inside the app
/// and keeps the user's own history.
class SupportInquiryScreen extends StatefulWidget {
  const SupportInquiryScreen({super.key});

  @override
  State<SupportInquiryScreen> createState() => _SupportInquiryScreenState();
}

class _SupportInquiryScreenState extends State<SupportInquiryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  SupportInquiryCategory _category = SupportInquiryCategory.analysis;

  @override
  void initState() {
    super.initState();
    // Prefilled, not fixed: a Kakao account without the email consent item
    // has none, and the user may want replies somewhere else anyway.
    _emailController.text = context.read<AuthProvider>().currentUser?.email ?? '';
    final provider = context.read<SupportInquiryProvider>();
    if (context.read<AuthProvider>().isAuthenticated) {
      WidgetsBinding.instance.addPostFrameCallback((_) => provider.loadInquiries());
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SupportInquiryProvider>();
    final sent = await provider.submit(
      email: _emailController.text.trim(),
      category: _category,
      message: _messageController.text.trim(),
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sent ? '문의가 접수되었어요. 입력하신 메일로 답변드릴게요.' : provider.errorMessage ?? '문의 접수에 실패했어요.')),
    );
    if (sent) {
      _messageController.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SupportInquiryProvider>();
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;

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
                  const Text('문의하기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  children: [
                    const _SectionLabel('문의 분류'),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final category in SupportInquiryCategory.values)
                          _CategoryChip(
                            key: Key('category_${category.code}'),
                            label: category.label,
                            selected: _category == category,
                            onTap: () => setState(() => _category = category),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('답변받을 이메일'),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('inquiryEmailField'),
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _fieldDecoration('name@example.com'),
                      validator: (value) {
                        final email = (value ?? '').trim();
                        if (email.isEmpty) return '답변받을 이메일을 입력해 주세요.';
                        if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
                          return '이메일 형식을 확인해 주세요.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionLabel('문의 내용'),
                    const SizedBox(height: 10),
                    TextFormField(
                      key: const Key('inquiryMessageField'),
                      controller: _messageController,
                      maxLines: 7,
                      maxLength: 2000,
                      decoration: _fieldDecoration('어떤 점이 불편하셨는지 자세히 알려주세요.'),
                      validator: (value) => (value ?? '').trim().isEmpty ? '문의 내용을 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 6),
                    PrimaryButton(
                      key: const Key('submitInquiryButton'),
                      label: '문의 보내기',
                      isLoading: provider.isSubmitting,
                      onPressed: provider.isSubmitting ? null : _submit,
                    ),
                    if (isAuthenticated) ...[
                      const SizedBox(height: AppSpacing.lg),
                      const _SectionLabel('내 문의 내역'),
                      const SizedBox(height: 10),
                      if (provider.isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (provider.inquiries.isEmpty)
                        const Text(
                          '아직 보낸 문의가 없어요.',
                          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                        )
                      else
                        for (final inquiry in provider.inquiries) ...[
                          _InquiryCard(inquiry: inquiry),
                          const SizedBox(height: 8),
                        ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 13.5, color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surfaceTint1,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.dividerStrong, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted));
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({super.key, required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surfaceTint3 : AppColors.surfaceTint1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.primary : AppColors.dividerStrong, width: 1.5),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  final SupportInquiryModel inquiry;

  const _InquiryCard({required this.inquiry});

  @override
  Widget build(BuildContext context) {
    final date = inquiry.createdAt;
    final formatted = '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

    return Container(
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.surfaceTint3, borderRadius: BorderRadius.circular(8)),
                child: Text(
                  inquiry.category.label,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              const Spacer(),
              Text(formatted, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inquiry.message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
          ),
        ],
      ),
    );
  }
}
