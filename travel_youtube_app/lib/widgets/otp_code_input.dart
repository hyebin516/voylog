import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';

const int otpCodeLength = 6;

/// Six boxes for a numeric verification code, backed by one hidden field.
///
/// The field opens the keyboard as soon as the screen appears and whenever a
/// box is tapped, and the next box to fill is outlined. Without that the
/// boxes looked like a read-only display: nothing was focused on arrival, no
/// caret showed anywhere, and users concluded there was no input at all.
class OtpCodeInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;

  /// Key for the underlying text field, so tests can enter a code.
  final Key? fieldKey;

  const OtpCodeInput({
    super.key,
    required this.controller,
    this.onChanged,
    this.fieldKey,
  });

  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_rebuild);
    widget.controller.addListener(_rebuild);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    _focusNode.dispose();
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  void _focus() {
    if (_focusNode.hasFocus) {
      // Already focused but the keyboard was dismissed -- bring it back.
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    } else {
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = widget.controller.text;
    final textTheme = Theme.of(context).textTheme;
    final activeIndex = code.length.clamp(0, otpCodeLength - 1);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Invisible but laid out at the boxes' size, so it can hold focus
          // and take keyboard input without cramped-constraint layout
          // errors. Taps are handled by the GestureDetector above, which
          // focuses it explicitly -- not by hit-testing an invisible field.
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  key: widget.fieldKey,
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(otpCodeLength),
                  ],
                  autofillHints: const [AutofillHints.oneTimeCode],
                  showCursor: false,
                  enableInteractiveSelection: false,
                  onChanged: widget.onChanged,
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(otpCodeLength, (i) {
              final filled = i < code.length;
              final active =
                  _focusNode.hasFocus &&
                  i == activeIndex &&
                  code.length < otpCodeLength;
              return Container(
                width: 44,
                height: 52,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? AppColors.primary
                        : (filled
                              ? AppColors.accentCyan
                              : AppColors.surfaceSoft),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: filled
                    ? Text(
                        code[i],
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : (active
                          ? Container(
                              width: 2,
                              height: 22,
                              color: AppColors.primary,
                            )
                          : null),
              );
            }),
          ),
        ],
      ),
    );
  }
}
