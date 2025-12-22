import 'package:flutter/cupertino.dart';

import 'widgets/chat_message.dart';
import 'widgets/composer_bar.dart';
import 'widgets/draggable_list_view.dart';

void main() => runApp(const ContextMenuApp());

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
          isTimestamp: i == 0,
          isSent: isSent,
          text: switch (i % 6) {
            0 => 'Quick check-in: are we still on for lunch?',
            1 => 'Yep! 12:30 works.',
            2 => "Perfect. I'll grab a table.",
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
          isTimestamp: false,
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
              child: DraggableListView(
                builder:
                    (
                      BuildContext context,
                      double dragOffset,
                      Animation<double> slideAnimation,
                    ) {
                      return ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16.0),
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        itemCount: _messages.length,
                        itemBuilder: (BuildContext context, int index) {
                          final _ChatMessageData msg = _messages[index];
                          // Find the last received message
                          final int lastReceivedIndex = _messages
                              .lastIndexWhere(
                                (_ChatMessageData m) => !m.isSent,
                              );
                          final bool isLastReceived =
                              !msg.isSent && index == lastReceivedIndex;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ChatMessage(
                              isTimestamp: msg.isTimestamp,
                              timestamp: _formatTime(msg.timestamp),
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
                                        : CupertinoColors.systemGrey5
                                              .resolveFrom(context)),
                              bubbleTextColor: msg.isSent
                                  ? CupertinoColors.white
                                  : theme.textTheme.textStyle.color ??
                                        CupertinoColors.label,
                              dragOffset: dragOffset,
                              slideAnimation: slideAnimation,
                              showEmojiChip: isLastReceived,
                            ),
                          );
                        },
                      );
                    },
              ),
            ),
            ComposerBar(
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

class _ChatMessageData {
  _ChatMessageData({
    required this.id,
    required this.isSent,
    required this.text,
    required this.timestamp,
    required this.isTimestamp,
  });

  final String id;
  final bool isSent;
  final String text;
  final DateTime timestamp;
  final bool isTimestamp;
}
