import 'package:flutter/cupertino.dart';

/// Message composer bar widget with input field and send button.
class ComposerBar extends StatelessWidget {
  const ComposerBar({
    super.key,
    required this.isDark,
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final bool isDark;
  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final EdgeInsets viewInsets = MediaQuery.viewInsetsOf(context);
    final Color background =
        isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final Color border =
        isDark ? const Color(0xFF2C2C2E) : const Color(0x00000000);

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          border: Border(top: BorderSide(color: border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: CupertinoTextField(
                    controller: controller,
                    focusNode: focusNode,
                    placeholder: 'Message',
                    onSubmitted: (_) => onSend(),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    clearButtonMode: OverlayVisibilityMode.editing,
                    textInputAction: TextInputAction.send,
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  onPressed: onSend,
                  child: const Icon(
                    CupertinoIcons.arrow_up_circle_fill,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
