import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../repositories/shared_route_repository.dart';

/// FR-21 공개 피드의 신고 시트. Google Play's user-generated content policy
/// requires an in-app way to flag content another user wrote; the feed's
/// titles are written by their authors, so the detail screen needs one.
///
/// Resolves to true once a report has been accepted, so the caller can
/// confirm it. Resolves to null when the sheet is simply dismissed.
Future<bool?> showReportRouteSheet(
  BuildContext context, {
  required String sharedRouteId,
  SharedRouteRepository? repository,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ReportRouteSheet(
      sharedRouteId: sharedRouteId,
      repository: repository,
    ),
  );
}

/// Kept in step with the backend's CHECK constraint (migration 033).
const reportReasons = <({String code, String label})>[
  (code: 'spam', label: '스팸이거나 광고예요'),
  (code: 'offensive', label: '욕설이나 혐오 표현이 있어요'),
  (code: 'sexual', label: '선정적인 내용이에요'),
  (code: 'illegal', label: '불법적인 내용이에요'),
  (code: 'copyright', label: '저작권을 침해했어요'),
  (code: 'other', label: '그 밖의 이유'),
];

class ReportRouteSheet extends StatefulWidget {
  const ReportRouteSheet({super.key, required this.sharedRouteId, this.repository});

  final String sharedRouteId;

  /// Defaults to the real repository. Widget tests inject a fake.
  final SharedRouteRepository? repository;

  @override
  State<ReportRouteSheet> createState() => _ReportRouteSheetState();
}

class _ReportRouteSheetState extends State<ReportRouteSheet> {
  late final SharedRouteRepository _repository = widget.repository ?? SharedRouteRepository();
  final _detailController = TextEditingController();

  String? _reason;
  bool _submitting = false;

  @override
  void dispose() {
    _detailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final reason = _reason;
    if (reason == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await _repository.report(widget.sharedRouteId, reason: reason, detail: _detailController.text);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('신고를 접수하지 못했어요. 잠시 후 다시 시도해 주세요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // The free-text field sits near the bottom; without this the keyboard
      // covers it.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
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
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const Text(
                '이 동선을 신고할까요?',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                '신고 사유를 하나 골라주세요. 접수된 내용은 운영자가 확인합니다.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 14),
              for (final reason in reportReasons)
                InkWell(
                  onTap: _submitting ? null : () => setState(() => _reason = reason.code),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    child: Row(
                      children: [
                        Icon(
                          _reason == reason.code
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: _reason == reason.code ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            reason.label,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: _reason == reason.code ? FontWeight.w600 : FontWeight.w500,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              TextField(
                controller: _detailController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 1000,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: '자세한 내용을 적어주세요 (선택)',
                  hintStyle: const TextStyle(fontSize: 14, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceTint2,
                  counterText: '',
                  contentPadding: const EdgeInsets.all(14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  // Nothing is submitted until a reason is picked -- a report
                  // without one tells the operator nothing.
                  onPressed: _reason == null || _submitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          '신고하기',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
