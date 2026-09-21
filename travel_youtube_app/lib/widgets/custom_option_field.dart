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
    this.compactWidth,
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

  /// When set, renders as a chip-sized pill of this width that sits inside
  /// the chip row itself, instead of a full-width field under it.
  final double? compactWidth;

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

    final width = widget.compactWidth;
    if (width != null) {
      return Container(
        width: width,
        height: 34,
        padding: const EdgeInsets.only(left: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceTint2,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            Icon(widget.icon, size: 14, color: AppColors.textTertiary),
            const SizedBox(width: 4),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryStrong),
                decoration: InputDecoration(
                  hintText: widget.hintText,
                  hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textTertiary),
                  isDense: true,
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            SizedBox(
              width: 32,
              height: 34,
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Icon(widget.submitIcon, size: 16),
                color: hasText ? AppColors.primary : AppColors.textTertiary,
                tooltip: widget.submitLabel,
                onPressed: hasText ? _submit : null,
              ),
            ),
          ],
        ),
      );
    }

    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.done,
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: Icon(widget.icon),
        suffixIcon: IconButton(
          icon: Icon(widget.submitIcon, size: 20),
          color: hasText ? AppColors.primary : AppColors.textTertiary,
          tooltip: widget.submitLabel,
          onPressed: hasText ? _submit : null,
        ),
      ),
    );
  }
}
