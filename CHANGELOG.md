## [1.0.2]

### 2025-12-19

- Fix intermittent white flash during the open transition by keeping the route on-stage while measuring, and deferring layout measurements until keys are mounted.
- Improve blur/barrier stability during the transition.
- Make `CupertinoContextMenuPlusController.open()` / `.close()` safe to call during build/layout by deferring to the next frame when needed.

## [1.0.1]

### 2025-12-19

- Add `bottomWidgetBuilder` as an alternative to `actions` for building fully custom content below the preview.
- Add `CupertinoContextMenuPlusController` to open/close the menu programmatically.
- Add `openGestureEnabled` to optionally disable the built-in long-press gesture.

## [1.0.0]

### 2025-12-19

- 🎉 Initial release.
