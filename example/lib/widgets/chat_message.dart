import 'package:cupertino_context_menu_plus/cupertino_context_menu_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

const List<String> _reactionImages = <String>[
  'assets/boom.gif',
  'assets/cry.gif',
  'assets/heart.gif',
  'assets/like.gif',
  'assets/love.gif',
  'assets/rofl.gif',
  'assets/more.png',
];

/// A chat message widget with context menu and timestamp reveal on drag.
class ChatMessage extends StatefulWidget {
  const ChatMessage({
    super.key,
    required this.text,
    required this.time,
    required this.isSent,
    required this.isDark,
    required this.bubbleColor,
    required this.bubbleTextColor,
    required this.dragOffset,
    required this.slideAnimation,
    required this.showEmojiChip,
    required this.isTimestamp,
    required this.timestamp,
  });

  final String text;
  final String time;
  final bool isSent;
  final bool isDark;
  final bool isTimestamp;
  final String timestamp;
  final Color bubbleColor;
  final Color bubbleTextColor;
  final double dragOffset;
  final Animation<double> slideAnimation;
  final bool showEmojiChip;

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  late final CupertinoContextMenuPlusController _menuController =
      CupertinoContextMenuPlusController();
  static const double _maxDragDistance = 80.0;

  @override
  void dispose() {
    _menuController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color actionsBackgroundColor = widget.isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF8F8F8);
    final BorderRadius actionsBorderRadius = BorderRadius.circular(18);

    final Widget bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: widget.bubbleColor,
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Text(
        widget.text,
        style: TextStyle(fontSize: 16, color: widget.bubbleTextColor),
      ),
    );

    final Widget emojiChip = CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: Size.zero,
      pressedOpacity: 0.7,
      onPressed: _menuController.open,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF2C2C2E)
              : const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: widget.isDark
                ? const Color(0xFF3A3A3C)
                : const Color(0x14000000),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: CupertinoColors.black.withValues(
                alpha: widget.isDark ? 0.35 : 0.12,
              ),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text('+', style: TextStyle(fontSize: 16)),
        ),
      ),
    );

    // Calculate the animated offset for smooth retraction
    final double animatedOffset = widget.slideAnimation.isAnimating
        ? widget.dragOffset * (1 - widget.slideAnimation.value)
        : widget.dragOffset;

    // Calculate timestamp opacity based on drag distance
    final double timestampOpacity = (widget.dragOffset.abs() / _maxDragDistance)
        .clamp(0.0, 1.0);

    // Build the timestamp that will be positioned off-screen
    final Widget timestamp = Opacity(
      opacity: timestampOpacity,
      child: Text(
        widget.time,
        style: TextStyle(
          fontSize: 13,
          color: widget.isDark
              ? CupertinoColors.systemGrey2
              : CupertinoColors.systemGrey,
          fontWeight: FontWeight.w500,
        ),
      ),
    );

    return Stack(
      children: [
        if (widget.isTimestamp)
          Center(child: Text(widget.timestamp))
        else
          Transform.translate(
            offset: Offset(animatedOffset, 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                // Message bubble in its normal position
                Align(
                  alignment: widget.isSent
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: CupertinoContextMenuPlus(
                      controller: _menuController,
                      openGestureEnabled: true,
                      onOpened: () => debugPrint('Context menu opened'),
                      previewLongPressTimeout: Duration(milliseconds: 250),
                      backdropBlurCurve: const Interval(
                        0.0,
                        0.18,
                        curve: Curves.easeOut,
                      ),
                      location: widget.isSent
                          ? CupertinoContextMenuLocation.right
                          : CupertinoContextMenuLocation.left,
                      showGrowAnimation: false,
                      enableHapticFeedback: true,
                      backdropBlurSigma: widget.isDark ? 12 : 10,
                      modalReverseTransitionDuration: Duration(
                        milliseconds: widget.isDark ? 160 : 180,
                      ),
                      barrierColor: widget.isDark
                          ? const Color(0x66000000)
                          : const Color(0x3304040F),
                      actionsBackgroundColor: actionsBackgroundColor,
                      actionsBorderRadius: actionsBorderRadius,
                      actions: _buildActions(
                        context,
                        isDark: widget.isDark,
                        text: widget.text,
                        time: widget.time,
                        isSent: widget.isSent,
                      ),
                      topWidget: _ReactionsTopWidget(isDark: widget.isDark),
                      child: bubble,
                    ),
                  ),
                ),
                // Timestamp positioned off-screen to the right, slides in with drag
                Positioned(
                  right:
                      -80, // Start off-screen (negative value pushes it outside)
                  top: 0,
                  bottom: 24,
                  child: Center(child: timestamp),
                ),
                // Emoji chip at bottom-left (only for last received message)
                if (widget.showEmojiChip)
                  Positioned(
                    left: 12,
                    bottom: 3,
                    child: AnimatedBuilder(
                      animation: _menuController,
                      child: emojiChip,
                      builder: (BuildContext context, Widget? child) {
                        final bool visible = !_menuController.isOpen;
                        return IgnorePointer(
                          ignoring: !visible,
                          child: AnimatedOpacity(
                            opacity: visible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOut,
                            child: child,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  static List<Widget> _buildActions(
    BuildContext context, {
    required bool isDark,
    required String text,
    required String time,
    required bool isSent,
  }) {
    final Color primaryText = isDark
        ? CupertinoColors.white
        : const Color(0xFF111111);
    final Color secondaryText = isDark
        ? CupertinoColors.systemGrey2
        : CupertinoColors.systemGrey;
    final Color tileBackground = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFFFFFFF);
    final Color divider = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0x14000000);

    return <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Row(
          children: <Widget>[
            Text(
              'Message',
              style: TextStyle(fontSize: 12, color: secondaryText),
            ),
            const Spacer(),
            Text(time, style: TextStyle(fontSize: 12, color: secondaryText)),
          ],
        ),
      ),
      _ActionGroup(
        background: tileBackground,
        divider: divider,
        children: <Widget>[
          _ActionTile(
            icon: CupertinoIcons.reply,
            label: 'Reply',
            labelColor: primaryText,
            iconColor: primaryText,
            onPressed: () => Navigator.pop(context),
          ),
          _ActionTile(
            icon: CupertinoIcons.doc_on_clipboard,
            label: 'Copy',
            labelColor: primaryText,
            iconColor: primaryText,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          _ActionTile(
            icon: CupertinoIcons.arrowshape_turn_up_right,
            label: 'Forward',
            labelColor: primaryText,
            iconColor: primaryText,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      const SizedBox(height: 10),
      _ActionGroup(
        background: tileBackground,
        divider: divider,
        children: <Widget>[
          _ActionTile(
            icon: isSent ? CupertinoIcons.delete : CupertinoIcons.info,
            label: isSent ? 'Delete' : 'Report',
            labelColor: CupertinoColors.destructiveRed,
            iconColor: CupertinoColors.destructiveRed,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      const SizedBox(height: 12),
    ];
  }
}

class _ReactionsTopWidget extends StatelessWidget {
  const _ReactionsTopWidget({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color background = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF2F2F7);
    final Color border = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0x00000000);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              'Tap + for more reactions',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? CupertinoColors.systemGrey2
                    : CupertinoColors.systemGrey,
              ),
            ),
            const SizedBox(height: 10),
            const _ReactionRow(),
          ],
        ),
      ),
    );
  }
}

class _ReactionRow extends StatelessWidget {
  const _ReactionRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: <Widget>[
        for (final String image in _reactionImages)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(image, height: 28, width: 28, fit: BoxFit.cover),
          ),
      ],
    );
  }
}

class _ActionGroup extends StatelessWidget {
  const _ActionGroup({
    required this.background,
    required this.divider,
    required this.children,
  });

  final Color background;
  final Color divider;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: DecoratedBox(
          decoration: BoxDecoration(color: background),
          child: Column(
            children: <Widget>[
              for (int i = 0; i < children.length; i += 1) ...<Widget>[
                children[i],
                if (i != children.length - 1)
                  Container(height: 0.5, color: divider),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.labelColor,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color labelColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: Size.zero,
      pressedOpacity: 0.55,
      onPressed: onPressed,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 15, color: labelColor),
            ),
          ),
        ],
      ),
    );
  }
}
