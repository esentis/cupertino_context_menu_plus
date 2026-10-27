## [2.0.0]

### 2026-10-27

- **Breaking:** Migrated from `package:flutter/cupertino.dart` to the standalone [`cupertino_ui`](https://pub.dev/packages/cupertino_ui) package. In apps built on `cupertino_ui` or `material_ui`, opening the menu threw `No CupertinoLocalizations found`.
- **Breaking:** Minimum SDK raised to Dart `3.12.0` / Flutter `3.44.0`, as required by `cupertino_ui`.
- Migration: run `flutter pub add cupertino_ui` and `dart fix --apply --code=migrate_design_widgets` in your app. Apps still on `package:flutter/cupertino.dart` or `package:flutter/material.dart` should stay on `cupertino_context_menu_plus: ^1.0.3`.

## [1.0.3]

### 2025-12-22

- Add `onOpened` callback to notify after the menu route is pushed (opening starts; not when the transition finishes).

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
