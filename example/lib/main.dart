import 'package:cupertino_context_menu_plus/cupertino_context_menu_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

void main() => runApp(const ContextMenuApp());

const List<String> _reactionImages = <String>[
  'assets/boom.gif',
  'assets/cry.gif',
  'assets/heart.gif',
  'assets/like.gif',
  'assets/love.gif',
  'assets/rofl.gif',
  'assets/more.png',
];

class ContextMenuApp extends StatefulWidget {
  const ContextMenuApp({super.key});

  @override
  State<ContextMenuApp> createState() => _ContextMenuAppState();
}

class _ContextMenuAppState extends State<ContextMenuApp> {
  Brightness _brightness = Brightness.light;

  void _toggleBrightness(Brightness brightness) {
    setState(() {
      _brightness = brightness;
    });
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: CupertinoThemeData(brightness: _brightness),
      home: ChatExample(
        brightness: _brightness,
        onBrightnessChanged: _toggleBrightness,
      ),
    );
  }
}

class ChatExample extends StatefulWidget {
  const ChatExample({
    super.key,
    required this.brightness,
    required this.onBrightnessChanged,
  });

  final Brightness brightness;
  final ValueChanged<Brightness> onBrightnessChanged;

  @override
  State<ChatExample> createState() => _ChatExampleState();
}

class _ChatExampleState extends State<ChatExample> {
  final List<_ChatMessageData> _messages = <_ChatMessageData>[];
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _composerFocusNode = FocusNode();

  bool get _isDark => widget.brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    _messages.addAll(_seedMessages());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: false);
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _composerFocusNode.dispose();
    super.dispose();
  }

  List<_ChatMessageData> _seedMessages() {
    final List<_ChatMessageData> seeded = <_ChatMessageData>[];
    final DateTime now = DateTime.now();
    for (int i = 0; i < 32; i += 1) {
      final bool isSent = i.isOdd;
      seeded.add(
        _ChatMessageData(
          id: 'seed_$i',
          isSent: isSent,
          text: switch (i % 6) {
            0 => 'Quick check-in: are we still on for lunch?',
            1 => 'Yep! 12:30 works.',
            2 => 'Perfect. I’ll grab a table.',
            3 => 'Want me to bring anything?',
            4 => 'Just your appetite.',
            _ => 'Deal. See you soon.',
          },
          timestamp: now.subtract(Duration(minutes: 50 - i)),
        ),
      );
    }
    return seeded;
  }

  String _formatTime(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final String suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${two(dt.minute)} $suffix';
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final double target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  void _sendMessage() {
    final String text = _composerController.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      _messages.add(
        _ChatMessageData(
          id: 'msg_${DateTime.now().microsecondsSinceEpoch}',
          isSent: true,
          text: text,
          timestamp: DateTime.now(),
        ),
      );
      _composerController.clear();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    final CupertinoThemeData theme = CupertinoTheme.of(context);
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('Chat Messages'),
        trailing: SizedBox(
          width: 170,
          child: CupertinoSlidingSegmentedControl<Brightness>(
            groupValue: widget.brightness,
            onValueChanged: (Brightness? value) {
              if (value == null) {
                return;
              }
              widget.onBrightnessChanged(value);
            },
            children: const <Brightness, Widget>{
              Brightness.light: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Light'),
              ),
              Brightness.dark: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('Dark'),
              ),
            },
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                itemCount: _messages.length,
                itemBuilder: (BuildContext context, int index) {
                  final _ChatMessageData msg = _messages[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ChatMessage(
                      text: msg.text,
                      time: _formatTime(msg.timestamp),
                      isSent: msg.isSent,
                      isDark: _isDark,
                      bubbleColor: msg.isSent
                          ? CupertinoDynamicColor.resolve(
                              CupertinoColors.activeBlue,
                              context,
                            )
                          : (_isDark
                                ? const Color(0xFF2C2C2E)
                                : CupertinoColors.systemGrey5.resolveFrom(
                                    context,
                                  )),
                      bubbleTextColor: msg.isSent
                          ? CupertinoColors.white
                          : theme.textTheme.textStyle.color ??
                                CupertinoColors.label,
                    ),
                  );
                },
              ),
            ),
            _ComposerBar(
              isDark: _isDark,
              controller: _composerController,
              focusNode: _composerFocusNode,
              onSend: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  const ChatMessage({
    super.key,
    required this.text,
    required this.time,
    required this.isSent,
    required this.isDark,
    required this.bubbleColor,
    required this.bubbleTextColor,
  });

  final String text;
  final String time;
  final bool isSent;
  final bool isDark;
  final Color bubbleColor;
  final Color bubbleTextColor;

  @override
  Widget build(BuildContext context) {
    final Color actionsBackgroundColor = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF8F8F8);
    final BorderRadius actionsBorderRadius = BorderRadius.circular(18);

    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: CupertinoContextMenuPlus(
        previewLongPressTimeout: const Duration(milliseconds: 350),
        location: isSent
            ? CupertinoContextMenuLocation.right
            : CupertinoContextMenuLocation.left,
        showGrowAnimation: false,
        enableHapticFeedback: true,
        backdropBlurSigma: isDark ? 12 : 10,
        backdropBlurCurve: const Interval(0.0, 0.25, curve: Curves.easeOut),
        backdropBlurReverseCurve: Curves.easeIn,
        modalReverseTransitionDuration: Duration(
          milliseconds: isDark ? 160 : 180,
        ),
        barrierColor: isDark
            ? const Color(0x66000000)
            : const Color(0x3304040F),
        actionsBackgroundColor: actionsBackgroundColor,
        actionsBorderRadius: actionsBorderRadius,
        actions: _buildSexyActions(
          context,
          isDark: isDark,
          text: text,
          time: time,
          isSent: isSent,
        ),
        topWidget: _ReactionsTopWidget(isDark: isDark),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            text,
            style: TextStyle(fontSize: 16, color: bubbleTextColor),
          ),
        ),
      ),
    );
  }

  static List<Widget> _buildSexyActions(
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

class _ComposerBar extends StatelessWidget {
  const _ComposerBar({
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
    final Color background = isDark
        ? const Color(0xFF1C1C1E)
        : const Color(0xFFF2F2F7);
    final Color border = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0x00000000);

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

class _ChatMessageData {
  _ChatMessageData({
    required this.id,
    required this.isSent,
    required this.text,
    required this.timestamp,
  });

  final String id;
  final bool isSent;
  final String text;
  final DateTime timestamp;
}
