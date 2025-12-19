# CupertinoContextMenuPlus

---

![image](https://i.ibb.co/cSRbz5BT/short-3.gif)

---

A forked and enhanced version of Flutter's `CupertinoContextMenu` with:

- `topWidget`: an optional widget shown above the preview when the menu opens.
- `bottomWidgetBuilder`: build a fully custom widget below the preview (alternative to `actions`).
- `controller` / `openGestureEnabled`: optionally open the menu programmatically (e.g. from an emoji button), and/or disable long-press.
- `location`: an optional override for consistent left/center/right alignment (useful for chat bubbles that may cross the screen midpoint).
- `showGrowAnimation`: optionally disable the small pre-open “grow” animation (decoy overlay) when pressing.
- `previewLongPressTimeout`: optionally change how long the user must press/hold before the menu opens.
- `actionsBackgroundColor` / `actionsBorderRadius`: customize the actions sheet container styling.
- `backdropBlurSigma` / `backdropBlurCurve` / `backdropBlurReverseCurve` / `barrierColor`: customize the modal backdrop blur ramp + dimming.
- `modalReverseTransitionDuration`: customize dismissal speed.
- Improved press (decoy) shadow: when possible, the animated shadow respects the child’s `borderRadius` instead of drawing as a plain rectangle.

## Usage

```dart
final controller = CupertinoContextMenuPlusController();

CupertinoContextMenuPlus(
  controller: controller,
  openGestureEnabled: false,
  location: CupertinoContextMenuLocation.right, // or .left / .center
  showGrowAnimation: false,
  backdropBlurSigma: 8,
  backdropBlurCurve: Interval(0.0, 0.25, curve: Curves.easeOut),
  backdropBlurReverseCurve: Curves.easeIn,
  modalReverseTransitionDuration: Duration(milliseconds: 180),
  barrierColor: const Color(0x3304040F),
  topWidget: YourReactionsRow(),
  bottomWidgetBuilder: (context) => ClipRSuperellipse(
    borderRadius: BorderRadius.circular(16),
    child: ColoredBox(
      color: CupertinoColors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CupertinoContextMenuAction(
            child: const Text('Reply'),
            onPressed: () {},
          ),
        ],
      ),
    ),
  ),
  child: Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      color: CupertinoColors.activeBlue,
    ),
    padding: const EdgeInsets.all(12),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Text('Message'),
        const SizedBox(width: 8),
        CupertinoButton(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          onPressed: controller.open,
          child: const Icon(CupertinoIcons.smiley),
        ),
      ],
    ),
  ),
)
```

Note: the decoy shadow can only reuse the border radius if it can be inferred from the child (e.g. `Container`/`DecoratedBox` with `BoxDecoration.borderRadius`, or a `ClipRRect`).
