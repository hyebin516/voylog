import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';

/// A one-line "or type your own" field that sits under a fixed chip list.
///
/// The chip lists in this app (home's hashtags, the wizard's regions and
/// themes) are curated, so anything not on the list was simply unreachable.
/// [onSubmitted] receives the trimmed, non-empty text; the field clears
/// itself afterwards so the next entry starts fresh.
class CustomOptionField extends StatefulWidget {
  const CustomOptionField({
    super.key,
    required this.hintText,
    required this.icon,
    required this.onSubmitted,
    this.submitLabel = '추가',
    this.submitIcon = Icons.add_rounded,
  });

  final String hintText;
  final IconData icon;
  final ValueChanged<String> onSubmitted;

  /// Tooltip/semantic label for the submit button -- "추가" where the entry
  /// joins a selection, "검색" where it runs straight away.
  final String submitLabel;

  /// Matches [submitLabel]: a plus where the entry joins a selection, a
  /// magnifier where submitting searches immediately.
  final IconData submitIcon;

  @override
  State<CustomOptionField> createState() => _CustomOptionFieldState();
}

class _CustomOptionFieldState extends State<CustomOptionField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    _controller.clear();
    setState(() {}); // the submit button follows whether there's text
    widget.onSubmitted(value);
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().isNotEmpty;

    // The handoff shows a labelled pill here ("추가"), not a bare icon --
    // an icon alone left it unclear that typing had to be confirmed.
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceTint2,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          Icon(widget.icon, size: 17, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.ink),
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textMuted),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: hasText ? _submit : null,
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: hasText ? AppColors.primary : AppColors.borderStrong,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                widget.submitLabel,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
