# CupertinoContextMenuPlus

A forked and enhanced version of Flutter's `CupertinoContextMenu` with:

- `topWidget`: an optional widget shown above the preview when the menu opens.
- `location`: an optional override for consistent left/center/right alignment (useful for chat bubbles that may cross the screen midpoint).
- `showGrowAnimation`: optionally disable the small pre-open “grow” animation (decoy overlay) when pressing.
- `previewLongPressTimeout`: optionally change how long the user must press/hold before the menu opens.
- Improved press (decoy) shadow: when possible, the animated shadow respects the child’s `borderRadius` instead of drawing as a plain rectangle.

## Usage

```dart
CupertinoContextMenuPlus(
  location: CupertinoContextMenuLocation.right, // or .left / .center
  showGrowAnimation: false,
  previewLongPressTimeout: Duration(milliseconds: 350),
  topWidget: YourReactionsRow(),
  actions: <Widget>[
    CupertinoContextMenuAction(child: Text('Reply'), onPressed: () {}),
  ],
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: CupertinoColors.activeBlue,
    ),
    padding: const EdgeInsets.all(12),
    child: const Text('Message'),
  ),
)
```

Note: the decoy shadow can only reuse the border radius if it can be inferred from the child (e.g. `Container`/`DecoratedBox` with `BoxDecoration.borderRadius`, or a `ClipRRect`).

