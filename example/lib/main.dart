import 'package:cupertino_context_menu_plus/cupertino_context_menu_plus.dart';
import 'package:flutter/cupertino.dart';

List<String> images = [
  'assets/boom.gif',
  'assets/cry.gif',
  'assets/heart.gif',
  'assets/like.gif',
  'assets/love.gif',
  'assets/rofl.gif',
  'assets/more.png',
];

void main() => runApp(const ContextMenuApp());

class ContextMenuApp extends StatelessWidget {
  const ContextMenuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      theme: CupertinoThemeData(brightness: Brightness.light),
      home: ChatExample(),
    );
  }
}

class ChatExample extends StatelessWidget {
  const ChatExample({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Chat Messages'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: const <Widget>[
            // Received message (left-aligned)
            ChatMessage(
              text: 'Hey! How are you doing?',
              time: '10:30 AM',
              isSent: false,
            ),
            SizedBox(height: 12),

            // Sent message (right-aligned)
            ChatMessage(
              text: 'I\'m doing great! Thanks for asking 😊',
              time: '10:32 AM',
              isSent: true,
            ),
            SizedBox(height: 12),

            // Received message
            ChatMessage(
              text: 'That\'s awesome! Want to grab lunch later?',
              time: '10:33 AM',
              isSent: false,
            ),
            SizedBox(height: 12),

            // Sent message
            ChatMessage(
              text: 'Sure! What time works for you?',
              time: '10:35 AM',
              isSent: true,
            ),
            SizedBox(height: 12),

            // Received message
            ChatMessage(
              text: 'How about 12:30?',
              time: '10:36 AM',
              isSent: false,
            ),
            SizedBox(height: 12),

            // Sent message
            ChatMessage(
              text: 'Perfect! See you then 👍',
              time: '10:37 AM',
              isSent: true,
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
  });

  final String text;
  final String time;
  final bool isSent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: CupertinoContextMenuPlus(
        previewLongPressTimeout: Duration(milliseconds: 350),
        location: isSent
            ? CupertinoContextMenuLocation.right
            : CupertinoContextMenuLocation.left,
        showGrowAnimation: false,
        backdropBlurSigma: 10,
        backdropBlurCurve: const Interval(0.0, 0.25, curve: Curves.easeOut),
        backdropBlurReverseCurve: Curves.easeIn,
        modalReverseTransitionDuration: const Duration(milliseconds: 180),
        barrierColor: const Color(0x3304040F),
        actionsBackgroundColor: CupertinoColors.white,
        actionsBorderRadius: BorderRadius.circular(16),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(left: 24.0, bottom: 12.0, top: 16.0),
            child: Text(
              time,
              style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Handle copy action
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.reply,
                  size: 20,
                  color: CupertinoColors.black,
                ),
                SizedBox(width: 16),
                Text(
                  'Reply',
                  style: TextStyle(color: CupertinoColors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Handle copy action
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.doc_on_clipboard,
                  size: 20,
                  color: CupertinoColors.black,
                ),
                SizedBox(width: 16),
                Text(
                  'Copy',
                  style: TextStyle(color: CupertinoColors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 12.0,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Handle forward action
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  CupertinoIcons.arrowshape_turn_up_right,
                  size: 20,
                  color: CupertinoColors.black,
                ),
                SizedBox(width: 16),
                Text(
                  'Forward',
                  style: TextStyle(color: CupertinoColors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          if (isSent)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              onPressed: () {
                Navigator.pop(context);
                // Handle delete action
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    CupertinoIcons.delete,
                    size: 20,
                    color: CupertinoColors.destructiveRed,
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          else
            CupertinoButton(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 12.0,
              ),
              onPressed: () {
                Navigator.pop(context);
                // Handle delete action
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    CupertinoIcons.info,
                    size: 20,
                    color: CupertinoColors.destructiveRed,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Report',
                    style: TextStyle(
                      color: CupertinoColors.destructiveRed,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(height: 12),
        ],
        topWidget: Container(
          width: MediaQuery.sizeOf(context).width,
          height: 72,
          decoration: BoxDecoration(
            color: CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(36.0),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              SizedBox(height: 4),
              Text(
                'Tap + for more reactions',
                style: TextStyle(
                  fontSize: 12,
                  color: CupertinoColors.systemGrey,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var image in images)
                      Image.asset(image, height: 32, width: 32),
                  ],
                ),
              ),
            ],
          ),
        ),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: isSent
                ? CupertinoColors.activeBlue
                : CupertinoColors.systemGrey5,
            borderRadius: BorderRadius.circular(20.0),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 16,
              color: isSent ? CupertinoColors.white : CupertinoColors.label,
            ),
          ),
        ),
      ),
    );
  }
}
