// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

// The scale of the child at the time that the CupertinoContextMenuPlus opens.
// This value was eyeballed from a physical device running iOS 13.1.2.
const double _kOpenScale = 1.15;

// The smallest possible scale of the child, used if opening the
// CupertinoContextMenuPlus would cause it to go outside the safe area. This value
// was eyeballed from the Xcode iPhone simulator running iOS 16.1.
const double _kMinScaleFactor = 1.02;

// The ratio for the borderRadius of the context menu preview image. This value
// was eyeballed by overlapping the CupertinoContextMenuPlus with a context menu
// from iOS 16.0 in the Xcode iPhone simulator.
const double _previewBorderRadiusRatio = 12.0;

// The duration of the transition used when a modal popup is shown. Eyeballed
// from a physical device running iOS 13.1.2.
const Duration _kModalPopupTransitionDuration = Duration(milliseconds: 335);

// The duration it takes for the CupertinoContextMenuPlus to open.
// This value was eyeballed from the Xcode simulator running iOS 16.0.
const Duration _kDefaultPreviewLongPressTimeout = Duration(milliseconds: 800);

// Barrier color for a Cupertino modal barrier.
const Color _kModalBarrierColor = Color(0x6604040F);

int _totalAnimationDurationMs(Duration previewLongPressTimeout) {
  return previewLongPressTimeout.inMilliseconds +
      _kModalPopupTransitionDuration.inMilliseconds;
}

// The final box shadow for the opening child widget.
// This value was eyeballed from the Xcode simulator running iOS 16.0.
const List<BoxShadow> _endBoxShadow = <BoxShadow>[
  BoxShadow(color: Color(0x40000000), blurRadius: 10.0, spreadRadius: 0.5),
];

const Color _kBackgroundColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF1F1F1),
  darkColor: Color(0xFF212122),
);

typedef _DismissCallback =
    void Function(BuildContext context, double scale, double opacity);

/// A function that builds the child and handles the transition between the
/// default child and the preview when the CupertinoContextMenuPlus is open.
typedef CupertinoContextMenuBuilder =
    Widget Function(BuildContext context, Animation<double> animation);

// Given a GlobalKey, return the Rect of the corresponding RenderBox's
// paintBounds in global coordinates.
Rect _getRect(GlobalKey globalKey) {
  assert(globalKey.currentContext != null);
  final RenderBox renderBoxContainer =
      globalKey.currentContext!.findRenderObject()! as RenderBox;
  return Rect.fromPoints(
    renderBoxContainer.localToGlobal(renderBoxContainer.paintBounds.topLeft),
    renderBoxContainer.localToGlobal(
      renderBoxContainer.paintBounds.bottomRight,
    ),
  );
}

// The context menu arranges itself slightly differently based on the location
// on the screen of [CupertinoContextMenuPlus.child] before the
// [CupertinoContextMenuPlus] opens.
///
/// This is used to determine how the preview, optional top widget, and actions
/// align horizontally when the context menu opens.
enum CupertinoContextMenuLocation { center, left, right }

enum _ContextMenuLocation { center, left, right }

_ContextMenuLocation _toInternalLocation(
  CupertinoContextMenuLocation location,
) {
  return switch (location) {
    CupertinoContextMenuLocation.center => _ContextMenuLocation.center,
    CupertinoContextMenuLocation.left => _ContextMenuLocation.left,
    CupertinoContextMenuLocation.right => _ContextMenuLocation.right,
  };
}

/// A full-screen modal route that opens when the [child] is long-pressed.
///
/// When open, the [CupertinoContextMenuPlus] shows the child in a large full-screen
/// [Overlay] with a list of buttons specified by [actions]. The child/preview is
/// placed in an [Expanded] widget so that it will grow to fill the Overlay if
/// its size is unconstrained.
///
/// When closed, the [CupertinoContextMenuPlus] displays the child as if the
/// [CupertinoContextMenuPlus] were not there. Sizing and positioning is unaffected.
/// The menu can be closed like other [PopupRoute]s, such as by tapping the
/// background or by calling `Navigator.pop(context)`. Unlike [PopupRoute], it can
/// also be closed by swiping downwards.
///
/// {@tool dartpad}
/// This sample shows a very simple [CupertinoContextMenuPlus] for the Flutter logo.
/// Long press on it to open.
///
/// ** See code in examples/api/lib/cupertino/context_menu/cupertino_context_menu.0.dart **
/// {@end-tool}
///
/// {@tool dartpad}
/// This sample shows a similar CupertinoContextMenuPlus, this time using [builder]
/// to add a border radius to the widget.
///
/// ** See code in examples/api/lib/cupertino/context_menu/cupertino_context_menu.1.dart **
/// {@end-tool}
///
/// See also:
///
///  * <https://developer.apple.com/design/human-interface-guidelines/ios/controls/context-menus/>
class CupertinoContextMenuPlus extends StatefulWidget {
  /// Default long-press duration before the menu opens.
  static const Duration kDefaultPreviewLongPressTimeout =
      _kDefaultPreviewLongPressTimeout;

  /// The point at which the CupertinoContextMenuPlus begins to animate
  /// into the open position for a given [previewLongPressTimeout].
  ///
  /// This corresponds to `previewLongPressTimeout / (previewLongPressTimeout + transitionDuration)`.
  static double animationOpensAtFor(Duration previewLongPressTimeout) {
    final int previewMs = previewLongPressTimeout.inMilliseconds;
    final int totalMs = _totalAnimationDurationMs(previewLongPressTimeout);
    if (previewMs <= 0 || totalMs <= 0) {
      return 0.0;
    }
    return previewMs / totalMs;
  }

  /// Create a context menu.
  ///
  /// The [actions] parameter cannot be empty.
  CupertinoContextMenuPlus({
    super.key,
    required this.actions,
    required Widget this.child,
    this.enableHapticFeedback = false,
    this.backdropBlurSigma = kDefaultBackdropBlurSigma,
    this.backdropBlurCurve = Curves.linear,
    this.backdropBlurReverseCurve = Curves.linear,
    this.barrierColor = kModalBarrierColor,
    this.modalTransitionDuration = _kModalPopupTransitionDuration,
    this.modalReverseTransitionDuration = _kModalPopupTransitionDuration,
    this.actionsBackgroundColor,
    this.actionsBorderRadius,
    this.topWidget,
    this.location,
    this.showGrowAnimation = true,
    this.previewLongPressTimeout = kDefaultPreviewLongPressTimeout,
  }) : assert(actions.isNotEmpty),
       assert(modalTransitionDuration > Duration.zero),
       assert(modalReverseTransitionDuration > Duration.zero),
       assert(previewLongPressTimeout > Duration.zero),
       builder = ((BuildContext context, Animation<double> animation) => child);

  /// Creates a context menu with a custom [builder] controlling the widget.
  ///
  /// Use instead of the default constructor when it is needed to have a more
  /// custom animation.
  ///
  /// The [actions] parameter cannot be empty.
  CupertinoContextMenuPlus.builder({
    super.key,
    required this.actions,
    required this.builder,
    this.enableHapticFeedback = false,
    this.backdropBlurSigma = kDefaultBackdropBlurSigma,
    this.backdropBlurCurve = Curves.linear,
    this.backdropBlurReverseCurve = Curves.linear,
    this.barrierColor = kModalBarrierColor,
    this.modalTransitionDuration = _kModalPopupTransitionDuration,
    this.modalReverseTransitionDuration = _kModalPopupTransitionDuration,
    this.actionsBackgroundColor,
    this.actionsBorderRadius,
    this.topWidget,
    this.location,
    this.showGrowAnimation = true,
    this.previewLongPressTimeout = kDefaultPreviewLongPressTimeout,
  }) : assert(actions.isNotEmpty),
       assert(modalTransitionDuration > Duration.zero),
       assert(modalReverseTransitionDuration > Duration.zero),
       assert(previewLongPressTimeout > Duration.zero),
       child = null;

  /// Exposes the default border radius for matching iOS 16.0 behavior. This
  /// value was eyeballed from the iOS simulator running iOS 16.0.
  ///
  /// {@tool snippet}
  ///
  /// Below is example code in order to match the default border radius for an
  /// iOS 16.0 open preview.
  ///
  /// ```dart
  /// CupertinoContextMenuPlus.builder(
  ///   actions: <Widget>[
  ///     CupertinoContextMenuAction(
  ///       child: const Text('Action one'),
  ///       onPressed: () {},
  ///     ),
  ///   ],
  ///   builder:(BuildContext context, Animation<double> animation) {
  ///     final Animation<BorderRadius?> borderRadiusAnimation = BorderRadiusTween(
  ///       begin: BorderRadius.circular(0.0),
  ///       end: BorderRadius.circular(CupertinoContextMenuPlus.kOpenBorderRadius),
  ///     ).animate(
  ///       CurvedAnimation(
  ///         parent: animation,
  ///         curve: Interval(
  ///           CupertinoContextMenuPlus.animationOpensAt,
  ///           1.0,
  ///         ),
  ///       ),
  ///     );
  ///
  ///     final Animation<Decoration> boxDecorationAnimation = DecorationTween(
  ///       begin: const BoxDecoration(
  ///        boxShadow: <BoxShadow>[],
  ///       ),
  ///       end: const BoxDecoration(
  ///        boxShadow: CupertinoContextMenuPlus.kEndBoxShadow,
  ///       ),
  ///      ).animate(
  ///        CurvedAnimation(
  ///         parent: animation,
  ///         curve: Interval(
  ///           0.0,
  ///           CupertinoContextMenuPlus.animationOpensAt,
  ///         ),
  ///       )
  ///     );
  ///
  ///     return Container(
  ///       decoration:
  ///         animation.value < CupertinoContextMenuPlus.animationOpensAt ? boxDecorationAnimation.value : null,
  ///       child: FittedBox(
  ///         fit: BoxFit.cover,
  ///         child: ClipRSuperellipse(
  ///           borderRadius: borderRadiusAnimation.value ?? BorderRadius.circular(0.0),
  ///           child: SizedBox(
  ///             height: 150,
  ///             width: 150,
  ///             child: Image.network('https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg'),
  ///           ),
  ///         ),
  ///       )
  ///     );
  ///   },
  /// )
  /// ```
  ///
  /// {@end-tool}
  static const double kOpenBorderRadius = _previewBorderRadiusRatio;

  /// Exposes the final box shadow of the opening animation of the child widget
  /// to match the default behavior of the native iOS widget. This value was
  /// eyeballed from the iOS simulator running iOS 16.0.
  static const List<BoxShadow> kEndBoxShadow = _endBoxShadow;

  /// The point at which the CupertinoContextMenuPlus begins to animate
  /// into the open position.
  ///
  /// This value is computed for the default [kDefaultPreviewLongPressTimeout].
  /// If you override [previewLongPressTimeout], use [animationOpensAtFor] to get
  /// the correct value.
  static final double animationOpensAt = animationOpensAtFor(
    kDefaultPreviewLongPressTimeout,
  );

  /// The background color of a [CupertinoContextMenuAction] and a
  /// [CupertinoContextMenuPlus] sheet.
  static const Color kBackgroundColor = _kBackgroundColor;

  /// Default blur sigma for the background behind the context menu route.
  ///
  /// Set [CupertinoContextMenuPlus.backdropBlurSigma] to `0.0` to disable blur.
  static const double kDefaultBackdropBlurSigma = 5.0;

  /// Default barrier color behind the context menu route.
  ///
  /// This controls the background dimming opacity.
  static const Color kModalBarrierColor = _kModalBarrierColor;

  /// Default border radius for the actions sheet container.
  static const BorderRadius kDefaultActionsBorderRadius = BorderRadius.all(
    Radius.circular(13.0),
  );

  /// A function that returns a widget to be used alternatively from [child].
  ///
  /// The widget returned by the function will be shown at all times: when the
  /// [CupertinoContextMenuPlus] is closed, when it is in the middle of opening,
  /// and when it is fully open. This will overwrite the default animation that
  /// matches the behavior of an iOS 16.0 context menu.
  ///
  /// This builder can be used instead of the child when the intended child has
  /// a property that would conflict with the default animation, such as a
  /// border radius or a shadow, or if a more custom animation is needed.
  ///
  /// In addition to the current [BuildContext], the function is also called
  /// with an [Animation]. The complete animation goes from 0 to 1 when
  /// the CupertinoContextMenuPlus opens, and from 1 to 0 when it closes, and it can
  /// be used to animate the widget in sync with this opening and closing.
  ///
  /// The animation works in two stages. The first happens on press and hold of
  /// the widget from 0 to [animationOpensAt], and the second stage for when the
  /// widget fully opens up to the menu, from [animationOpensAt] to 1.
  ///
  /// {@tool snippet}
  ///
  /// Below is an example of using [builder] to show an image tile setup to be
  /// opened in the default way to match a native iOS 16.0 app. The behavior
  /// will match what will happen if the simple child image was passed as just
  /// the [child] parameter, instead of [builder]. This can be manipulated to
  /// add more customizability to the widget's animation.
  ///
  /// ```dart
  /// CupertinoContextMenuPlus.builder(
  ///   actions: <Widget>[
  ///     CupertinoContextMenuAction(
  ///       child: const Text('Action one'),
  ///       onPressed: () {},
  ///     ),
  ///   ],
  ///   builder:(BuildContext context, Animation<double> animation) {
  ///     final Animation<BorderRadius?> borderRadiusAnimation = BorderRadiusTween(
  ///       begin: BorderRadius.circular(0.0),
  ///       end: BorderRadius.circular(CupertinoContextMenuPlus.kOpenBorderRadius),
  ///     ).animate(
  ///       CurvedAnimation(
  ///         parent: animation,
  ///         curve: Interval(
  ///           CupertinoContextMenuPlus.animationOpensAt,
  ///           1.0,
  ///         ),
  ///       ),
  ///      );
  ///
  ///     final Animation<Decoration> boxDecorationAnimation = DecorationTween(
  ///       begin: const BoxDecoration(
  ///        boxShadow: <BoxShadow>[],
  ///       ),
  ///       end: const BoxDecoration(
  ///        boxShadow: CupertinoContextMenuPlus.kEndBoxShadow,
  ///       ),
  ///      ).animate(
  ///        CurvedAnimation(
  ///         parent: animation,
  ///         curve: Interval(
  ///           0.0,
  ///           CupertinoContextMenuPlus.animationOpensAt,
  ///         ),
  ///       ),
  ///     );
  ///
  ///     return Container(
  ///       decoration:
  ///         animation.value < CupertinoContextMenuPlus.animationOpensAt ? boxDecorationAnimation.value : null,
  ///       child: FittedBox(
  ///         fit: BoxFit.cover,
  ///         child: ClipRSuperellipse(
  ///           borderRadius: borderRadiusAnimation.value ?? BorderRadius.circular(0.0),
  ///           child: SizedBox(
  ///             height: 150,
  ///             width: 150,
  ///             child: Image.network('https://flutter.github.io/assets-for-api-docs/assets/widgets/owl-2.jpg'),
  ///           ),
  ///         ),
  ///       ),
  ///     );
  ///   },
  /// )
  /// ```
  ///
  /// {@end-tool}
  ///
  /// {@tool dartpad}
  /// Additionally below is an example of a real world use case for [builder].
  ///
  /// If a widget is passed to the [child] parameter with properties that
  /// conflict with the default animation, in this case the border radius,
  /// unwanted behaviors can arise. Here a boxed shadow will wrap the widget as
  /// it is expanded. To handle this, a more custom animation and widget can be
  /// passed to the builder, using values exposed by [CupertinoContextMenuPlus],
  /// like [CupertinoContextMenuPlus.kEndBoxShadow], to match the native iOS
  /// animation as close as desired.
  ///
  /// ** See code in examples/api/lib/cupertino/context_menu/cupertino_context_menu.1.dart **
  /// {@end-tool}
  final CupertinoContextMenuBuilder builder;

  // TODO(mitchgoodwin): deprecate [child] with builder refactor https://github.com/flutter/flutter/issues/116306

  /// The widget that can be "opened" with the [CupertinoContextMenuPlus].
  ///
  /// When the [CupertinoContextMenuPlus] is long-pressed, the menu will open and
  /// this widget will be moved to the new route and placed inside of an
  /// [Expanded] widget. This allows the child to resize to fit in its place in
  /// the new route, if it doesn't size itself.
  ///
  /// When the [CupertinoContextMenuPlus] is "closed", this widget acts like a
  /// [Container], i.e. it does not constrain its child's size or affect its
  /// position.
  final Widget? child;

  /// The actions that are shown in the menu.
  ///
  /// These actions are typically [CupertinoContextMenuAction]s.
  ///
  /// This parameter must not be empty.
  final List<Widget> actions;

  /// Blur strength applied to the background behind the menu route.
  ///
  /// Set to `0.0` to disable blur.
  final double backdropBlurSigma;

  /// Controls how quickly the blur ramps in/out during the route transition.
  ///
  /// Defaults to [Curves.linear]. For a faster blur, consider:
  /// `Interval(0.0, 0.25, curve: Curves.easeOut)`.
  final Curve backdropBlurCurve;

  /// Controls how quickly the blur ramps out during dismissal.
  ///
  /// Defaults to [Curves.linear]. To make blur leave faster, consider:
  /// `Curves.easeIn`.
  final Curve backdropBlurReverseCurve;

  /// The modal barrier color behind the menu route.
  ///
  /// This controls the dimming/opacity of the background while the menu is open.
  final Color barrierColor;

  /// The route transition duration for showing the context menu.
  ///
  /// This controls how quickly the menu animates into place (not the long-press
  /// time).
  final Duration modalTransitionDuration;

  /// The route transition duration for dismissing the context menu.
  final Duration modalReverseTransitionDuration;

  /// Background color for the actions sheet container.
  ///
  /// Defaults to [kBackgroundColor].
  ///
  /// This can be a [CupertinoDynamicColor]; it will be resolved against the
  /// current [BuildContext] when the menu is shown.
  final Color? actionsBackgroundColor;

  /// Border radius for the actions sheet container clip.
  ///
  /// Defaults to [kDefaultActionsBorderRadius].
  final BorderRadius? actionsBorderRadius;

  /// If true, accepting the long-press (opening the menu) produces haptic
  /// feedback.
  ///
  /// Uses [HapticFeedback.heavyImpact] when the gesture is accepted.
  ///
  /// Note: this does not automatically add haptics to the action widgets; if
  /// you need that, trigger haptics in your action callbacks.
  /// Defaults to false.
  final bool enableHapticFeedback;

  /// An optional widget to be shown above the child when the context menu is opened.
  ///
  /// This widget will be positioned on top of the [child] widget when the menu
  /// opens, providing additional context or information.
  final Widget? topWidget;

  /// Overrides the automatically detected horizontal alignment used when the
  /// context menu opens.
  ///
  /// By default, the alignment is inferred from the child's on-screen position.
  /// For chat UIs where bubbles can be wide enough to cross the screen's
  /// midpoint, setting this explicitly avoids the menu sometimes aligning to
  /// the center for some messages but not others.
  final CupertinoContextMenuLocation? location;

  /// Whether to show the small "press preview" grow animation before the context
  /// menu route opens.
  ///
  /// When false, the child stays visually unchanged while pressing/holding, and
  /// the context menu opens without the pre-grow decoy animation.
  final bool showGrowAnimation;

  /// How long the user must press and hold before the context menu opens.
  ///
  /// Defaults to [kDefaultPreviewLongPressTimeout].
  final Duration previewLongPressTimeout;

  @override
  State<CupertinoContextMenuPlus> createState() =>
      _CupertinoContextMenuPlusState();
}

class _CupertinoContextMenuPlusState extends State<CupertinoContextMenuPlus>
    with TickerProviderStateMixin {
  final GlobalKey _childGlobalKey = GlobalKey();
  bool _childHidden = false;
  // Animates the child while it's opening.
  late AnimationController _openController;
  Rect? _decoyChildEndRect;
  late double _scaleFactor;
  OverlayEntry? _lastOverlayEntry;
  _ContextMenuRoute<void>? _route;
  late final TapGestureRecognizer _tapGestureRecognizer;

  double get _animationOpensAt => CupertinoContextMenuPlus.animationOpensAtFor(
    widget.previewLongPressTimeout,
  );

  double get _midpoint => _animationOpensAt / 2;

  @override
  void initState() {
    super.initState();
    _openController = AnimationController(
      duration: widget.previewLongPressTimeout,
      vsync: this,
      upperBound: _animationOpensAt,
    );
    _openController.addStatusListener(_onDecoyAnimationStatusChange);
    _tapGestureRecognizer = TapGestureRecognizer()
      ..onTapCancel = _onTapCancel
      ..onTapDown = _onTapDown
      ..onTapUp = _onTapUp
      ..onTap = _onTap;
  }

  @override
  void didUpdateWidget(CupertinoContextMenuPlus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.previewLongPressTimeout != widget.previewLongPressTimeout) {
      _dismissContextMenuRoute();
      _closeContextMenu();
      _openController.removeStatusListener(_onDecoyAnimationStatusChange);
      _openController.dispose();
      _openController = AnimationController(
        duration: widget.previewLongPressTimeout,
        vsync: this,
        upperBound: _animationOpensAt,
      )..addStatusListener(_onDecoyAnimationStatusChange);
      _openController.reset();
      if (mounted) {
        setState(() {
          _childHidden = false;
        });
      }
    }
  }

  void _dismissContextMenuRoute() {
    final _ContextMenuRoute<void>? route = _route;
    if (route == null) {
      return;
    }

    route.animation?.removeStatusListener(_routeAnimationStatusListener);
    route.navigator?.removeRoute(route);
    _route = null;
  }

  void _listenerCallback() {
    if (_openController.status != AnimationStatus.reverse &&
        _openController.value >= _midpoint) {
      if (widget.enableHapticFeedback) {
        HapticFeedback.heavyImpact();
      }
      _tapGestureRecognizer.resolve(GestureDisposition.accepted);
      _openController.removeListener(_listenerCallback);
    }
  }

  // Determine the _ContextMenuLocation based on the location of the original
  // child in the screen.
  //
  // The location of the original child is used to determine how to horizontally
  // align the content of the open CupertinoContextMenuPlus. For example, if the
  // child is near the center of the screen, it will also appear in the center
  // of the screen when the menu is open, and the actions will be centered below
  // it.
  _ContextMenuLocation get _contextMenuLocation {
    final CupertinoContextMenuLocation? override = widget.location;
    if (override != null) {
      return _toInternalLocation(override);
    }

    final Rect childRect = _getRect(_childGlobalKey);
    final double screenWidth = MediaQuery.widthOf(context);

    final double center = screenWidth / 2;
    final bool centerDividesChild =
        childRect.left < center && childRect.right > center;
    final double distanceFromCenter = (center - childRect.center.dx).abs();
    if (centerDividesChild && distanceFromCenter <= childRect.width / 4) {
      return _ContextMenuLocation.center;
    }

    if (childRect.center.dx > center) {
      return _ContextMenuLocation.right;
    }

    return _ContextMenuLocation.left;
  }

  // Constrain the size of the expanded child so that it does not go outside the
  // safe area.
  //
  // See https://github.com/flutter/flutter/issues/122951.
  static double _getScaleFactor(Rect childRect, EdgeInsets padding, Size size) {
    final double leftMaxScale =
        2 * (childRect.center.dx - padding.left) / childRect.width;
    final double topMaxScale =
        2 * (childRect.center.dy - padding.top) / childRect.height;
    final double rightMaxScale =
        2 *
        (size.width - padding.right - childRect.center.dx) /
        childRect.width;
    final double bottomMaxScale =
        2 *
        (size.height - padding.bottom - childRect.center.dy) /
        childRect.height;
    final double minWidth = math.min(leftMaxScale, rightMaxScale);
    final double minHeight = math.min(topMaxScale, bottomMaxScale);

    // Return the smallest scale factor that keeps the child mostly onscreen.
    return clampDouble(
      math.min(minWidth, minHeight),
      _kMinScaleFactor,
      _kOpenScale,
    );
  }

  /// The default preview builder if none is provided. It makes a rectangle
  /// around the child widget with rounded borders, matching the iOS 16 opened
  /// context menu eyeballed on the Xcode iOS simulator.
  static Widget _defaultPreviewBuilder(
    BuildContext context,
    Animation<double> animation,
    Widget child,
  ) {
    return FittedBox(
      fit: BoxFit.cover,
      child: ClipRSuperellipse(
        borderRadius: BorderRadius.circular(
          _previewBorderRadiusRatio * animation.value,
        ),
        child: child,
      ),
    );
  }

  // Push the new route and open the CupertinoContextMenuPlus overlay.
  void _openContextMenu() {
    setState(() {
      _childHidden = true;
    });

    _route = _ContextMenuRoute<void>(
      actions: widget.actions,
      barrierLabel: CupertinoLocalizations.of(context).menuDismissLabel,
      contextMenuLocation: _contextMenuLocation,
      previousChildRect: _decoyChildEndRect!,
      previousChildRectWasScaled: widget.showGrowAnimation,
      scaleFactor: _scaleFactor,
      topWidget: widget.topWidget,
      backdropBlurSigma: widget.backdropBlurSigma,
      backdropBlurCurve: widget.backdropBlurCurve,
      backdropBlurReverseCurve: widget.backdropBlurReverseCurve,
      barrierColor: widget.barrierColor,
      transitionDuration: widget.modalTransitionDuration,
      reverseTransitionDuration: widget.modalReverseTransitionDuration,
      actionsBackgroundColor: widget.actionsBackgroundColor,
      actionsBorderRadius: widget.actionsBorderRadius,
      builder: (BuildContext context, Animation<double> animation) {
        if (widget.child == null) {
          final double animationOpensAt = _animationOpensAt;
          final Animation<double> localAnimation = Tween<double>(
            begin: animationOpensAt,
            end: 1,
          ).animate(animation);
          return widget.builder(context, localAnimation);
        }
        return _defaultPreviewBuilder(context, animation, widget.child!);
      },
    );
    Navigator.of(context, rootNavigator: true).push<void>(_route!);
    _route!.animation!.addStatusListener(_routeAnimationStatusListener);
  }

  void _removeContextMenuDecoy() {
    // Keep the decoy on the screen for one extra frame. We have to do this
    // because _ContextMenuRoute renders its first frame offscreen.
    // Otherwise there would be a visible flash when nothing is rendered for
    // one frame.
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _closeContextMenu();
        _openController.reset();
      }
    }, debugLabel: 'removeContextMenuDecoy');
  }

  void _closeContextMenu() {
    _lastOverlayEntry?.remove();
    _lastOverlayEntry?.dispose();
    _lastOverlayEntry = null;
  }

  void _onDecoyAnimationStatusChange(AnimationStatus animationStatus) {
    switch (animationStatus) {
      case AnimationStatus.dismissed:
        if (_route == null) {
          setState(() {
            _childHidden = false;
          });
        }
        _closeContextMenu();
      case AnimationStatus.completed:
        _openContextMenu();
        _removeContextMenuDecoy();
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        if (!ModalRoute.of(context)!.isCurrent) {
          _removeContextMenuDecoy();
        }
        return;
    }
  }

  // Watch for when _ContextMenuRoute is closed and return to the state where
  // the CupertinoContextMenuPlus just behaves as a Container.
  void _routeAnimationStatusListener(AnimationStatus status) {
    if (!status.isDismissed) {
      return;
    }
    if (mounted) {
      setState(() {
        _childHidden = false;
      });
    }
    _route!.animation!.removeStatusListener(_routeAnimationStatusListener);
    _route = null;
  }

  void _onTapCompleted() {
    _openController.removeListener(_listenerCallback);
    if (_openController.isAnimating && _openController.value < _midpoint) {
      _openController.reverse();
    }
  }

  void _onTap() {
    _onTapCompleted();
  }

  void _onTapCancel() {
    _onTapCompleted();
  }

  void _onTapUp(TapUpDetails details) {
    _onTapCompleted();
  }

  void _onTapDown(TapDownDetails details) {
    _openController.addListener(_listenerCallback);
    final Rect childRect = _getRect(_childGlobalKey);
    _scaleFactor = _getScaleFactor(
      childRect,
      MediaQuery.paddingOf(context),
      MediaQuery.sizeOf(context),
    );

    if (widget.showGrowAnimation) {
      setState(() {
        _childHidden = true;
      });

      _decoyChildEndRect = Rect.fromCenter(
        center: childRect.center,
        width: childRect.width * _scaleFactor,
        height: childRect.height * _scaleFactor,
      );

      // Create a decoy child in an overlay directly on top of the original child.
      // TODO(justinmc): There is a known inconsistency with native here, due to
      // doing the bounce animation using a decoy in the top level Overlay. The
      // decoy will pop on top of the AppBar if the child is partially behind it,
      // such as a top item in a partially scrolled view. However, if we don't use
      // an overlay, then the decoy will appear behind its neighboring widget when
      // it expands. This may be solvable by adding a widget to Scaffold that's
      // underneath the AppBar.
      _lastOverlayEntry = OverlayEntry(
        builder: (BuildContext context) {
          return _DecoyChild(
            beginRect: childRect,
            controller: _openController,
            endRect: _decoyChildEndRect,
            previewLongPressTimeout: widget.previewLongPressTimeout,
            animationOpensAt: _animationOpensAt,
            builder: widget.builder,
            child: widget.child,
          );
        },
      );
      Overlay.of(
        context,
        rootOverlay: true,
        debugRequiredFor: widget,
      ).insert(_lastOverlayEntry!);
    } else {
      _decoyChildEndRect = childRect;
    }

    _openController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: Listener(
        onPointerDown: _tapGestureRecognizer.addPointer,
        child: TickerMode(
          enabled: !_childHidden,
          child: Visibility.maintain(
            key: _childGlobalKey,
            visible: !_childHidden,
            child: widget.builder(context, _openController),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _dismissContextMenuRoute();
    _closeContextMenu();
    _tapGestureRecognizer.dispose();
    _openController.dispose();
    super.dispose();
  }
}

// A floating copy of the CupertinoContextMenuPlus's child.
//
// When the child is pressed, but before the CupertinoContextMenuPlus opens, it does
// an animation where it slowly grows. This is implemented by hiding the
// original child and placing _DecoyChild on top of it in an Overlay. The use of
// an Overlay allows the _DecoyChild to appear on top of siblings of the
// original child.
class _DecoyChild extends StatefulWidget {
  const _DecoyChild({
    this.beginRect,
    required this.controller,
    this.endRect,
    required this.previewLongPressTimeout,
    required this.animationOpensAt,
    this.child,
    this.builder,
  });

  final Rect? beginRect;
  final AnimationController controller;
  final Rect? endRect;
  final Duration previewLongPressTimeout;
  final double animationOpensAt;
  final Widget? child;
  final CupertinoContextMenuBuilder? builder;

  @override
  _DecoyChildState createState() => _DecoyChildState();
}

class _DecoyChildState extends State<_DecoyChild>
    with TickerProviderStateMixin {
  late Animation<Rect?> _rect;
  late Animation<Decoration> _boxDecoration;
  late final CurvedAnimation _boxDecorationCurvedAnimation;

  static BorderRadiusGeometry? _tryExtractBorderRadius(Widget child) {
    if (child is ClipRRect) {
      return child.borderRadius;
    }

    final Decoration? decoration = switch (child) {
      Container() => child.decoration,
      DecoratedBox() => child.decoration,
      _ => null,
    };

    return switch (decoration) {
      BoxDecoration() => decoration.borderRadius,
      _ => null,
    };
  }

  @override
  void initState() {
    super.initState();

    const double beginPause = 1.0;
    const double openAnimationLength = 5.0;
    const double totalOpenAnimationLength = beginPause + openAnimationLength;
    final int previewMs = widget.previewLongPressTimeout.inMilliseconds;
    final int totalMs = _totalAnimationDurationMs(
      widget.previewLongPressTimeout,
    );
    final double endPause =
        ((totalOpenAnimationLength * totalMs) / previewMs) -
        totalOpenAnimationLength;

    // The timing on the animation was eyeballed from the Xcode iOS simulator
    // running iOS 16.0.
    // Because the animation no longer goes from 0.0 to 1.0, but to a number
    // depending on the ratio between the press animation time and the opening
    // animation time, a pause needs to be added to the end of the tween
    // sequence that completes that ratio. This is to allow the animation to
    // fully complete as expected without doing crazy math to the _kOpenScale
    // value. This change was necessary from the inclusion of the builder and
    // the complete animation value that it passes along.
    _rect = TweenSequence<Rect?>(<TweenSequenceItem<Rect?>>[
      TweenSequenceItem<Rect?>(
        tween: RectTween(
          begin: widget.beginRect,
          end: widget.beginRect,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: beginPause,
      ),
      TweenSequenceItem<Rect?>(
        tween: RectTween(
          begin: widget.beginRect,
          end: widget.endRect,
        ).chain(CurveTween(curve: Curves.easeOutSine)),
        weight: openAnimationLength,
      ),
      TweenSequenceItem<Rect?>(
        tween: RectTween(
          begin: widget.endRect,
          end: widget.endRect,
        ).chain(CurveTween(curve: Curves.linear)),
        weight: endPause,
      ),
    ]).animate(widget.controller);

    _boxDecorationCurvedAnimation = CurvedAnimation(
      parent: widget.controller,
      curve: Interval(0.0, widget.animationOpensAt),
    );

    final BorderRadiusGeometry? borderRadius = widget.child != null
        ? _tryExtractBorderRadius(widget.child!)
        : null;

    _boxDecoration = DecorationTween(
      begin: BoxDecoration(
        boxShadow: const <BoxShadow>[],
        borderRadius: borderRadius,
      ),
      end: BoxDecoration(boxShadow: _endBoxShadow, borderRadius: borderRadius),
    ).animate(_boxDecorationCurvedAnimation);
  }

  Widget _buildAnimation(BuildContext context, Widget? child) {
    return Positioned.fromRect(
      rect: _rect.value!,
      child: Container(decoration: _boxDecoration.value, child: widget.child),
    );
  }

  Widget _buildBuilder(BuildContext context, Widget? child) {
    return Positioned.fromRect(
      rect: _rect.value!,
      child: widget.builder!(context, widget.controller),
    );
  }

  @override
  void dispose() {
    _boxDecorationCurvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        AnimatedBuilder(
          builder: widget.child != null ? _buildAnimation : _buildBuilder,
          animation: widget.controller,
        ),
      ],
    );
  }
}

// The open CupertinoContextMenuPlus modal.
class _ContextMenuRoute<T> extends PopupRoute<T> {
  // Build a _ContextMenuRoute.
  _ContextMenuRoute({
    required List<Widget> actions,
    required _ContextMenuLocation contextMenuLocation,
    this.barrierLabel,
    required CupertinoContextMenuBuilder builder,
    required Rect previousChildRect,
    required bool previousChildRectWasScaled,
    required double scaleFactor,
    super.settings,
    Widget? topWidget,
    required double backdropBlurSigma,
    required Curve backdropBlurCurve,
    required Curve backdropBlurReverseCurve,
    required Color barrierColor,
    required Duration transitionDuration,
    required Duration reverseTransitionDuration,
    Color? actionsBackgroundColor,
    BorderRadius? actionsBorderRadius,
  }) : assert(actions.isNotEmpty),
       assert(backdropBlurSigma >= 0.0),
       assert(transitionDuration > Duration.zero),
       assert(reverseTransitionDuration > Duration.zero),
       _actions = actions,
       _builder = builder,
       _contextMenuLocation = contextMenuLocation,
       _previousChildRect = previousChildRect,
       _previousChildRectWasScaled = previousChildRectWasScaled,
       _scaleFactor = scaleFactor,
       _topWidget = topWidget,
       _backdropBlurSigma = backdropBlurSigma,
       _backdropBlurCurve = backdropBlurCurve,
       _backdropBlurReverseCurve = backdropBlurReverseCurve,
       _barrierColor = barrierColor,
       _transitionDuration = transitionDuration,
       _reverseTransitionDuration = reverseTransitionDuration,
       _actionsBackgroundColor = actionsBackgroundColor,
       _actionsBorderRadius = actionsBorderRadius;

  final List<Widget> _actions;
  final CupertinoContextMenuBuilder _builder;
  final GlobalKey _childGlobalKey = GlobalKey();
  final _ContextMenuLocation _contextMenuLocation;
  bool _externalOffstage = false;
  bool _internalOffstage = false;
  final double _scaleFactor;
  Orientation? _lastOrientation;
  // The Rect of the child at the moment that the CupertinoContextMenuPlus opens.
  final Rect _previousChildRect;
  final bool _previousChildRectWasScaled;
  double? _scale = 1.0;
  final GlobalKey _sheetGlobalKey = GlobalKey();
  final GlobalKey _topWidgetGlobalKey = GlobalKey();
  final Widget? _topWidget;
  final double _backdropBlurSigma;
  final Curve _backdropBlurCurve;
  final Curve _backdropBlurReverseCurve;
  final Color _barrierColor;
  final Duration _transitionDuration;
  final Duration _reverseTransitionDuration;
  final Color? _actionsBackgroundColor;
  final BorderRadius? _actionsBorderRadius;

  static final CurveTween _curve = CurveTween(curve: Curves.easeOutBack);
  static final CurveTween _curveReverse = CurveTween(curve: Curves.easeInBack);
  static final RectTween _rectTween = RectTween();
  static final Animatable<Rect?> _rectAnimatable = _rectTween.chain(_curve);
  static final RectTween _rectTweenReverse = RectTween();
  static final Animatable<Rect?> _rectAnimatableReverse = _rectTweenReverse
      .chain(_curveReverse);
  static final RectTween _sheetRectTween = RectTween();
  final Animatable<Rect?> _sheetRectAnimatable = _sheetRectTween.chain(_curve);
  final Animatable<Rect?> _sheetRectAnimatableReverse = _sheetRectTween.chain(
    _curveReverse,
  );
  static final RectTween _topWidgetRectTween = RectTween();
  final Animatable<Rect?> _topWidgetRectAnimatable = _topWidgetRectTween.chain(
    _curve,
  );
  final Animatable<Rect?> _topWidgetRectAnimatableReverse = _topWidgetRectTween
      .chain(_curveReverse);
  static final Tween<double> _sheetScaleTween = Tween<double>();
  static final Animatable<double> _sheetScaleAnimatable = _sheetScaleTween
      .chain(_curve);
  static final Animatable<double> _sheetScaleAnimatableReverse =
      _sheetScaleTween.chain(_curveReverse);
  final Tween<double> _opacityTween = Tween<double>(begin: 0.0, end: 1.0);
  late Animation<double> _sheetOpacity;

  @override
  final String? barrierLabel;

  @override
  Color get barrierColor => _barrierColor;

  @override
  bool get barrierDismissible => true;

  @override
  bool get semanticsDismissible => false;

  @override
  Widget buildModalBarrier() {
    final Animation<double>? routeAnimation = animation;
    if (routeAnimation == null) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: routeAnimation,
      builder: (BuildContext context, Widget? child) {
        final double t = routeAnimation.value;
        final bool reversing = routeAnimation.status == AnimationStatus.reverse;
        final double blurT = clampDouble(
          (reversing ? _backdropBlurReverseCurve : _backdropBlurCurve)
              .transform(t),
          0.0,
          1.0,
        );
        final Color resolvedBarrierColor = CupertinoDynamicColor.resolve(
          _barrierColor,
          context,
        );
        final Color color = resolvedBarrierColor.withValues(
          alpha: resolvedBarrierColor.a * t,
        );

        Widget barrier = ModalBarrier(
          dismissible: barrierDismissible,
          color: color,
          barrierSemanticsDismissible: semanticsDismissible,
          semanticsLabel: barrierLabel,
        );

        final double sigma = _backdropBlurSigma * blurT;
        if (sigma > 0.0) {
          barrier = BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: barrier,
          );
        }

        return barrier;
      },
    );
  }

  @override
  Duration get transitionDuration => _transitionDuration;

  @override
  Duration get reverseTransitionDuration => _reverseTransitionDuration;

  CurvedAnimation? _curvedAnimation;

  CurvedAnimation? _sheetOpacityCurvedAnimation;

  // Getting the RenderBox doesn't include the scale from the Transform.scale,
  // so it's manually accounted for here.
  static Rect _getScaledRect(GlobalKey globalKey, double scale) {
    final Rect childRect = _getRect(globalKey);
    final Size sizeScaled = childRect.size * scale;
    final Offset offsetScaled = Offset(
      childRect.left + (childRect.size.width - sizeScaled.width) / 2,
      childRect.top + (childRect.size.height - sizeScaled.height) / 2,
    );
    return offsetScaled & sizeScaled;
  }

  // Get the alignment for the _ContextMenuSheet's Transform.scale based on the
  // contextMenuLocation and orientation.
  static AlignmentDirectional getSheetAlignment(
    _ContextMenuLocation contextMenuLocation,
    Orientation orientation,
  ) {
    return switch (contextMenuLocation) {
      _ContextMenuLocation.center when orientation == Orientation.landscape =>
        AlignmentDirectional.topStart,
      _ContextMenuLocation.center => AlignmentDirectional.topCenter,
      _ContextMenuLocation.right => AlignmentDirectional.topEnd,
      _ContextMenuLocation.left => AlignmentDirectional.topStart,
    };
  }

  // The place to start the sheetRect animation from.
  static Rect _getSheetRectBegin(
    Orientation? orientation,
    _ContextMenuLocation contextMenuLocation,
    Rect childRect,
    Rect sheetRect,
  ) {
    switch (contextMenuLocation) {
      case _ContextMenuLocation.center:
        final Offset target = orientation == Orientation.portrait
            ? childRect.bottomCenter
            : childRect.topCenter;
        final Offset centered = target - Offset(sheetRect.width / 2, 0.0);
        return centered & sheetRect.size;
      case _ContextMenuLocation.right:
        final Offset target = orientation == Orientation.portrait
            ? childRect.bottomRight
            : childRect.topRight;
        return (target - Offset(sheetRect.width, 0.0)) & sheetRect.size;
      case _ContextMenuLocation.left:
        final Offset target = orientation == Orientation.portrait
            ? childRect.bottomLeft
            : childRect.topLeft;
        return target & sheetRect.size;
    }
  }

  void _onDismiss(BuildContext context, double scale, double opacity) {
    _scale = scale;
    _opacityTween.end = opacity;
    _sheetOpacityCurvedAnimation = CurvedAnimation(
      parent: animation!,
      curve: const Interval(0.9, 1.0),
    );
    _sheetOpacity = _opacityTween.animate(_sheetOpacityCurvedAnimation!);
    Navigator.of(context).pop();
  }

  // Take measurements on the child and _ContextMenuSheet and update the
  // animation tweens to match.
  void _updateTweenRects() {
    final Rect childRect = _scale == null
        ? _getRect(_childGlobalKey)
        : _getScaledRect(_childGlobalKey, _scale!);
    _rectTween.begin = _previousChildRect;
    _rectTween.end = childRect;

    // When opening, the transition happens from the end of the child's bounce
    // animation to the final state. When closing, it goes from the final state
    // to the original position before the bounce.
    final Rect childRectOriginal = _previousChildRectWasScaled
        ? Rect.fromCenter(
            center: _previousChildRect.center,
            width: _previousChildRect.width / _scaleFactor,
            height: _previousChildRect.height / _scaleFactor,
          )
        : _previousChildRect;

    final Rect sheetRect = _getRect(_sheetGlobalKey);
    final Rect sheetRectBegin = _getSheetRectBegin(
      _lastOrientation,
      _contextMenuLocation,
      childRectOriginal,
      sheetRect,
    );
    _sheetRectTween.begin = sheetRectBegin;
    _sheetRectTween.end = sheetRect;
    _sheetScaleTween.begin = 0.0;
    _sheetScaleTween.end = _scale;

    _rectTweenReverse.begin = childRectOriginal;
    _rectTweenReverse.end = childRect;

    // Update top widget rect if it exists
    if (_topWidget != null) {
      if (_topWidgetGlobalKey.currentContext == null) {
        return;
      }
      final Rect topWidgetRect = _getRect(_topWidgetGlobalKey);
      final Rect topWidgetRectBegin = _getSheetRectBegin(
        _lastOrientation,
        _contextMenuLocation,
        childRectOriginal,
        topWidgetRect,
      );
      _topWidgetRectTween.begin = topWidgetRectBegin;
      _topWidgetRectTween.end = topWidgetRect;
    }
  }

  void _setOffstageInternally() {
    super.offstage = _externalOffstage || _internalOffstage;
    // It's necessary to call changedInternalState to get the backdrop to
    // update.
    changedInternalState();
  }

  @override
  bool didPop(T? result) {
    _updateTweenRects();
    return super.didPop(result);
  }

  @override
  set offstage(bool value) {
    _externalOffstage = value;
    _setOffstageInternally();
  }

  @override
  TickerFuture didPush() {
    _internalOffstage = true;
    _setOffstageInternally();

    // Render one frame offstage in the final position so that we can take
    // measurements of its layout and then animate to them.
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _updateTweenRects();
      _internalOffstage = false;
      _setOffstageInternally();
    }, debugLabel: 'renderContextMenuRouteOffstage');
    return super.didPush();
  }

  @override
  Animation<double> createAnimation() {
    final Animation<double> animation = super.createAnimation();
    if (_curvedAnimation?.parent != animation) {
      _curvedAnimation?.dispose();
      _curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.linear,
      );
    }
    _sheetOpacity = _opacityTween.animate(_curvedAnimation!);
    return animation;
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // This is usually used to build the "page", which is then passed to
    // buildTransitions as child, the idea being that buildTransitions will
    // animate the entire page into the scene. In the case of _ContextMenuRoute,
    // two individual pieces of the page are animated into the scene in
    // buildTransitions, and a SizedBox.shrink() is returned here.
    return const SizedBox.shrink();
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return OrientationBuilder(
      builder: (BuildContext context, Orientation orientation) {
        _lastOrientation = orientation;

        // While the animation is running, render everything in a Stack so that
        // they're movable.
        if (!animation.isCompleted) {
          final bool reverse = animation.status == AnimationStatus.reverse;
          final Rect rect = reverse
              ? _rectAnimatableReverse.evaluate(animation)!
              : _rectAnimatable.evaluate(animation)!;
          final Rect sheetRect = reverse
              ? _sheetRectAnimatableReverse.evaluate(animation)!
              : _sheetRectAnimatable.evaluate(animation)!;
          final double sheetScale = reverse
              ? _sheetScaleAnimatableReverse.evaluate(animation)
              : _sheetScaleAnimatable.evaluate(animation);
          final Rect? topWidgetRect = _topWidget != null
              ? (reverse
                    ? _topWidgetRectAnimatableReverse.evaluate(animation)
                    : _topWidgetRectAnimatable.evaluate(animation))
              : null;
          return Stack(
            children: <Widget>[
              Positioned.fromRect(
                rect: sheetRect,
                child: FadeTransition(
                  opacity: _sheetOpacity,
                  child: Transform.scale(
                    alignment: getSheetAlignment(
                      _contextMenuLocation,
                      orientation,
                    ),
                    scale: sheetScale,
                    child: _ContextMenuSheet(
                      key: _sheetGlobalKey,
                      actions: _actions,
                      contextMenuLocation: _contextMenuLocation,
                      orientation: orientation,
                      actionsBackgroundColor: _actionsBackgroundColor,
                      actionsBorderRadius: _actionsBorderRadius,
                    ),
                  ),
                ),
              ),
              if (_topWidget != null && topWidgetRect != null)
                Positioned.fromRect(
                  key: _topWidgetGlobalKey,
                  rect: topWidgetRect,
                  child: FadeTransition(
                    opacity: _sheetOpacity,
                    child: Transform.scale(
                      alignment: getSheetAlignment(
                        _contextMenuLocation,
                        orientation,
                      ),
                      scale: sheetScale,
                      child: _topWidget,
                    ),
                  ),
                ),
              Positioned.fromRect(
                key: _childGlobalKey,
                rect: rect,
                child: _builder(context, animation),
              ),
            ],
          );
        }

        // When the animation is done, just render everything in a static layout
        // in the final position.
        return _ContextMenuRouteStatic(
          actions: _actions,
          childGlobalKey: _childGlobalKey,
          contextMenuLocation: _contextMenuLocation,
          onDismiss: _onDismiss,
          orientation: orientation,
          sheetGlobalKey: _sheetGlobalKey,
          topWidgetGlobalKey: _topWidgetGlobalKey,
          childRect: _previousChildRect,
          topWidget: _topWidget,
          actionsBackgroundColor: _actionsBackgroundColor,
          actionsBorderRadius: _actionsBorderRadius,
          child: _builder(context, animation),
        );
      },
    );
  }

  @override
  void dispose() {
    _curvedAnimation?.dispose();
    _sheetOpacityCurvedAnimation?.dispose();
    super.dispose();
  }
}

// The final state of the _ContextMenuRoute after animating in and before
// animating out.
class _ContextMenuRouteStatic extends StatefulWidget {
  const _ContextMenuRouteStatic({
    this.actions,
    required this.child,
    this.childGlobalKey,
    required this.contextMenuLocation,
    this.onDismiss,
    required this.orientation,
    this.sheetGlobalKey,
    this.topWidgetGlobalKey,
    required this.childRect,
    this.topWidget,
    this.actionsBackgroundColor,
    this.actionsBorderRadius,
  });

  final List<Widget>? actions;
  final Widget child;
  final GlobalKey? childGlobalKey;
  final _ContextMenuLocation contextMenuLocation;
  final _DismissCallback? onDismiss;
  final Orientation orientation;
  final GlobalKey? sheetGlobalKey;
  final GlobalKey? topWidgetGlobalKey;
  final Rect childRect;
  final Widget? topWidget;
  final Color? actionsBackgroundColor;
  final BorderRadius? actionsBorderRadius;

  @override
  _ContextMenuRouteStaticState createState() => _ContextMenuRouteStaticState();
}

class _ContextMenuRouteStaticState extends State<_ContextMenuRouteStatic>
    with TickerProviderStateMixin {
  // The child is scaled down as it is dragged down until it hits this minimum
  // value.
  static const double _kMinScale = 0.8;
  // The CupertinoContextMenuSheet disappears at this scale.
  static const double _kSheetScaleThreshold = 0.9;
  static const double _kPadding = 20.0;
  static const double _kDamping = 400.0;
  static const Duration _kMoveControllerDuration = Duration(milliseconds: 600);

  late Offset _dragOffset;
  double _lastScale = 1.0;
  late final AnimationController _moveController;
  late final CurvedAnimation _moveCurvedAnimation;
  late final AnimationController _sheetController;
  late final CurvedAnimation _sheetCurvedAnimation;
  late Animation<Offset> _moveAnimation;
  late Animation<double> _sheetScaleAnimation;
  late Animation<double> _sheetOpacityAnimation;

  // The scale of the child changes as a function of the distance it is dragged.
  static double _getScale(
    Orientation orientation,
    double maxDragDistance,
    double dy,
  ) {
    final double dyDirectional = dy <= 0.0 ? dy : -dy;
    return math.max(
      _kMinScale,
      (maxDragDistance + dyDirectional) / maxDragDistance,
    );
  }

  void _onPanStart(DragStartDetails details) {
    _moveController.value = 1.0;
    _setDragOffset(Offset.zero);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    _setDragOffset(_dragOffset + details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    // If flung, animate a bit before handling the potential dismiss.
    if (details.velocity.pixelsPerSecond.dy.abs() >= kMinFlingVelocity) {
      final bool flingIsAway = details.velocity.pixelsPerSecond.dy > 0;
      final double finalPosition = flingIsAway
          ? _moveAnimation.value.dy + 100.0
          : 0.0;

      if (flingIsAway && _sheetController.status != AnimationStatus.forward) {
        _sheetController.forward();
      } else if (!flingIsAway &&
          _sheetController.status != AnimationStatus.reverse) {
        _sheetController.reverse();
      }

      _moveAnimation = Tween<Offset>(
        begin: Offset(0.0, _moveAnimation.value.dy),
        end: Offset(0.0, finalPosition),
      ).animate(_moveController);
      _moveController.reset();
      _moveController.duration = const Duration(milliseconds: 64);
      _moveController.forward();
      _moveController.addStatusListener(_flingStatusListener);
      return;
    }

    // Dismiss if the drag is enough to scale down all the way.
    if (_lastScale == _kMinScale) {
      widget.onDismiss!(context, _lastScale, _sheetOpacityAnimation.value);
      return;
    }

    // Otherwise animate back home.
    _moveController.addListener(_moveListener);
    _moveController.reverse();
  }

  void _moveListener() {
    // When the scale passes the threshold, animate the sheet back in.
    if (_lastScale > _kSheetScaleThreshold) {
      _moveController.removeListener(_moveListener);
      if (!_sheetController.isDismissed) {
        _sheetController.reverse();
      }
    }
  }

  void _flingStatusListener(AnimationStatus status) {
    if (!status.isCompleted) {
      return;
    }

    // Reset the duration back to its original value.
    _moveController.duration = _kMoveControllerDuration;

    _moveController.removeStatusListener(_flingStatusListener);
    // If it was a fling back to the start, it has reset itself, and it should
    // not be dismissed.
    if (_moveAnimation.value.dy == 0.0) {
      return;
    }
    widget.onDismiss!(context, _lastScale, _sheetOpacityAnimation.value);
  }

  void _setDragOffset(Offset dragOffset) {
    // Allow horizontal and negative vertical movement, but damp it.
    final double endX = _kPadding * dragOffset.dx / _kDamping;
    final double endY = dragOffset.dy >= 0.0
        ? dragOffset.dy
        : _kPadding * dragOffset.dy / _kDamping;
    setState(() {
      _dragOffset = dragOffset;
      _moveAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(clampDouble(endX, -_kPadding, _kPadding), endY),
      ).animate(_moveCurvedAnimation);

      // Fade the _ContextMenuSheet out or in, if needed.
      if (_lastScale <= _kSheetScaleThreshold &&
          _sheetController.status != AnimationStatus.forward &&
          _sheetScaleAnimation.value != 0.0) {
        _sheetController.forward();
      } else if (_lastScale > _kSheetScaleThreshold &&
          _sheetController.status != AnimationStatus.reverse &&
          _sheetScaleAnimation.value != 1.0) {
        _sheetController.reverse();
      }
    });
  }

  // The order and alignment of the _ContextMenuSheet and the child depend on
  // both the orientation of the screen as well as the position on the screen of
  // the original child.
  Widget _getChild(
    Orientation orientation,
    _ContextMenuLocation contextMenuLocation,
  ) {
    final Size screenSize = MediaQuery.sizeOf(context);
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    final Rect screenBounds = Rect.fromLTWH(
      0,
      0,
      screenSize.width - padding.left - padding.right,
      screenSize.height - padding.top - padding.bottom,
    );

    final Widget sheet = AnimatedBuilder(
      animation: _sheetController,
      builder: _buildSheetAnimation,
      child: _ContextMenuSheet(
        key: widget.sheetGlobalKey,
        actions: widget.actions!,
        contextMenuLocation: widget.contextMenuLocation,
        orientation: widget.orientation,
        actionsBackgroundColor: widget.actionsBackgroundColor,
        actionsBorderRadius: widget.actionsBorderRadius,
      ),
    );

    // Animate top widget similar to the sheet
    final Widget? animatedTopWidget = widget.topWidget != null
        ? AnimatedBuilder(
            key: widget.topWidgetGlobalKey,
            animation: _sheetController,
            builder: _buildSheetAnimation,
            child: widget.topWidget,
          )
        : null;

    final Widget child = _ContextMenuAlignedChildren(
      targetRect: widget.childRect,
      screenBounds: screenBounds,
      sheet: sheet,
      contextMenuLocation: contextMenuLocation,
      orientation: widget.orientation,
      topWidget: animatedTopWidget,
      child: AnimatedBuilder(
        animation: _moveController,
        builder: _buildChildAnimation,
        child: widget.child,
      ),
    );

    return child;
  }

  // Build the animation for the _ContextMenuSheet.
  Widget _buildSheetAnimation(BuildContext context, Widget? child) {
    return Transform.scale(
      alignment: _ContextMenuRoute.getSheetAlignment(
        widget.contextMenuLocation,
        widget.orientation,
      ),
      scale: _sheetScaleAnimation.value,
      child: FadeTransition(opacity: _sheetOpacityAnimation, child: child),
    );
  }

  // Build the animation for the child.
  Widget _buildChildAnimation(BuildContext context, Widget? child) {
    _lastScale = _getScale(
      widget.orientation,
      MediaQuery.heightOf(context),
      _moveAnimation.value.dy,
    );
    return Transform.scale(
      key: widget.childGlobalKey,
      scale: _lastScale,
      child: child,
    );
  }

  // Build the animation for the overall draggable dismissible content.
  Widget _buildAnimation(BuildContext context, Widget? child) {
    return Transform.translate(offset: _moveAnimation.value, child: child);
  }

  @override
  void initState() {
    super.initState();
    _moveController = AnimationController(
      duration: _kMoveControllerDuration,
      value: 1.0,
      vsync: this,
    );
    _moveCurvedAnimation = CurvedAnimation(
      parent: _moveController,
      curve: Curves.elasticIn,
    );
    _sheetController = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _sheetCurvedAnimation = CurvedAnimation(
      parent: _sheetController,
      curve: Curves.linear,
      reverseCurve: Curves.easeInBack,
    );
    _sheetScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_sheetCurvedAnimation);
    _sheetOpacityAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_sheetController);
    _setDragOffset(Offset.zero);
  }

  @override
  void dispose() {
    _moveController.dispose();
    _moveCurvedAnimation.dispose();
    _sheetController.dispose();
    _sheetCurvedAnimation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget child = _getChild(
      widget.orientation,
      widget.contextMenuLocation,
    );

    return SafeArea(
      child: Align(
        alignment: Alignment.topLeft,
        child: GestureDetector(
          onPanEnd: _onPanEnd,
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          child: AnimatedBuilder(
            animation: _moveController,
            builder: _buildAnimation,
            child: child,
          ),
        ),
      ),
    );
  }
}

// The menu that displays when CupertinoContextMenuPlus is open. It consists of a
// list of actions that are typically CupertinoContextMenuActions.
class _ContextMenuSheet extends StatefulWidget {
  _ContextMenuSheet({
    super.key,
    required this.actions,
    required this.contextMenuLocation,
    required this.orientation,
    this.actionsBackgroundColor,
    this.actionsBorderRadius,
  }) : assert(actions.isNotEmpty);

  final List<Widget> actions;
  final _ContextMenuLocation contextMenuLocation;
  final Orientation orientation;
  final Color? actionsBackgroundColor;
  final BorderRadius? actionsBorderRadius;

  @override
  State<_ContextMenuSheet> createState() => _ContextMenuSheetState();
}

class _ContextMenuSheetState extends State<_ContextMenuSheet> {
  late final ScrollController _controller;
  static const double _kMenuMaxWidth = 250.0;
  // Eyeballed on a context menu on an iOS 15 simulator running iOS 17.5.
  static const double _kScrollbarMainAxisMargin = 13.0;

  @override
  void initState() {
    super.initState();
    // Link the scrollbar to the scroll view by providing both the same scroll
    // controller. Using SingleChildScrollview.primary might conflict with users
    // already using the PrimaryScrollController.
    _controller = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = CupertinoDynamicColor.resolve(
      widget.actionsBackgroundColor ??
          CupertinoContextMenuPlus.kBackgroundColor,
      context,
    );
    final BorderRadius borderRadius =
        widget.actionsBorderRadius ??
        CupertinoContextMenuPlus.kDefaultActionsBorderRadius;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _kMenuMaxWidth),
      child: IntrinsicWidth(
        child: IntrinsicHeight(
          child: ClipRSuperellipse(
            borderRadius: borderRadius,
            child: ColoredBox(
              color: backgroundColor,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(
                  context,
                ).copyWith(scrollbars: false),
                child: CupertinoScrollbar(
                  mainAxisMargin: _kScrollbarMainAxisMargin,
                  controller: _controller,
                  child: SingleChildScrollView(
                    controller: _controller,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        widget.actions.first,
                        for (final Widget action in widget.actions.skip(1))
                          action,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ContextMenuChild { child, menuSheet, topWidget }

class _ContextMenuAlignedChildren extends StatelessWidget {
  const _ContextMenuAlignedChildren({
    required this.targetRect,
    required this.screenBounds,
    required this.child,
    required this.sheet,
    required this.orientation,
    required this.contextMenuLocation,
    this.topWidget,
  });
  final Rect targetRect;
  final Rect screenBounds;
  final Widget child;
  final Widget sheet;
  final Orientation orientation;
  final _ContextMenuLocation contextMenuLocation;
  final Widget? topWidget;

  @override
  Widget build(BuildContext context) {
    return CustomMultiChildLayout(
      delegate: _ContextMenuAlignedChildrenDelegate(
        targetRect: targetRect,
        screenBounds: screenBounds,
        orientation: orientation,
        contextMenuLocation: contextMenuLocation,
        hasTopWidget: topWidget != null,
      ),
      children: <Widget>[
        LayoutId(id: _ContextMenuChild.child, child: child),
        LayoutId(id: _ContextMenuChild.menuSheet, child: sheet),
        if (topWidget != null)
          LayoutId(id: _ContextMenuChild.topWidget, child: topWidget!),
      ],
    );
  }
}

class _ContextMenuAlignedChildrenDelegate extends MultiChildLayoutDelegate {
  _ContextMenuAlignedChildrenDelegate({
    required this.targetRect,
    required this.screenBounds,
    required this.orientation,
    required this.contextMenuLocation,
    required this.hasTopWidget,
  });
  final Rect targetRect;
  final Rect screenBounds;
  final Orientation orientation;
  final _ContextMenuLocation contextMenuLocation;
  final bool hasTopWidget;

  @override
  void performLayout(Size size) {
    final BoxConstraints constraints = BoxConstraints.loose(size);

    final double availableHeightForChild =
        screenBounds.height - _ContextMenuRouteStaticState._kPadding;
    final double availableWidth =
        screenBounds.width - _ContextMenuRouteStaticState._kPadding * 2;
    final double availableWidthForChild = switch (orientation) {
      Orientation.portrait => availableWidth,
      Orientation.landscape =>
        availableWidth - _ContextMenuSheetState._kMenuMaxWidth,
    };
    assert(availableWidthForChild >= 0.0);
    assert(availableHeightForChild >= 0.0);

    // Layout top widget if it exists
    Size? topWidgetSize;
    if (hasTopWidget) {
      topWidgetSize = layoutChild(
        _ContextMenuChild.topWidget,
        constraints.copyWith(maxWidth: availableWidthForChild),
      );
    }

    final double topWidgetHeight = topWidgetSize != null
        ? topWidgetSize.height + _ContextMenuRouteStaticState._kPadding
        : 0.0;

    final Size childSize = layoutChild(
      _ContextMenuChild.child,
      constraints.copyWith(
        maxHeight: availableHeightForChild - topWidgetHeight,
        maxWidth: availableWidthForChild,
      ),
    );

    // In portrait orientation, the child is atop the menu, while in landscape
    // orientation, the child is beside the menu.
    final double availableHeightForMenu = switch (orientation) {
      Orientation.portrait =>
        availableHeightForChild -
            topWidgetHeight -
            (childSize.height + _ContextMenuRouteStaticState._kPadding),
      Orientation.landscape => availableHeightForChild - topWidgetHeight,
    };

    final Size menuSize = layoutChild(
      _ContextMenuChild.menuSheet,
      constraints.copyWith(maxHeight: availableHeightForMenu),
    );

    // Use the maximum width to ensure alignment
    final double maxWidth = math.max(
      topWidgetSize?.width ?? 0.0,
      math.max(childSize.width, menuSize.width),
    );

    final double initialChildLeft;
    final double initialChildTop;
    final double maxClampedLeft;
    final double maxClampedTop;
    switch (orientation) {
      case Orientation.portrait:
        final double totalHeight =
            topWidgetHeight +
            childSize.height +
            menuSize.height +
            _ContextMenuRouteStaticState._kPadding;
        final double totalWidth =
            maxWidth + _ContextMenuRouteStaticState._kPadding;

        // Align based on context menu location
        initialChildLeft = switch (contextMenuLocation) {
          _ContextMenuLocation.left => targetRect.left,
          _ContextMenuLocation.right => targetRect.right - maxWidth,
          _ContextMenuLocation.center => targetRect.center.dx - maxWidth / 2,
        };
        initialChildTop =
            targetRect.center.dy - childSize.height + topWidgetHeight;

        maxClampedLeft = screenBounds.right - totalWidth;
        maxClampedTop = screenBounds.bottom - totalHeight;
      case Orientation.landscape:
        final double totalWidth =
            childSize.width +
            menuSize.width +
            _ContextMenuRouteStaticState._kPadding;
        final double totalHeightLandscape =
            topWidgetHeight + math.max(childSize.height, menuSize.height);
        initialChildLeft = screenBounds.center.dx - totalWidth / 2;
        initialChildTop =
            screenBounds.center.dy - totalHeightLandscape / 2 + topWidgetHeight;
        maxClampedLeft = screenBounds.right - totalWidth;
        maxClampedTop = screenBounds.bottom - topWidgetHeight;
    }

    // Clamp the position to ensure it stays within screen bounds.
    // Ensure min <= max to avoid assertion errors
    final double minLeft =
        screenBounds.left + _ContextMenuRouteStaticState._kPadding;
    final double minTop =
        screenBounds.top +
        _ContextMenuRouteStaticState._kPadding +
        topWidgetHeight;

    final double clampedLeft = clampDouble(
      initialChildLeft,
      minLeft,
      math.max(minLeft, maxClampedLeft),
    );
    final double clampedTop = clampDouble(
      initialChildTop,
      minTop,
      math.max(minTop, maxClampedTop),
    );

    // Calculate individual positions based on context menu location and orientation
    if (orientation == Orientation.portrait) {
      final double childLeft = switch (contextMenuLocation) {
        _ContextMenuLocation.left => clampedLeft,
        _ContextMenuLocation.right => clampedLeft + maxWidth - childSize.width,
        _ContextMenuLocation.center =>
          clampedLeft + (maxWidth - childSize.width) / 2,
      };

      final double menuLeft = switch (contextMenuLocation) {
        _ContextMenuLocation.left => clampedLeft,
        _ContextMenuLocation.right => clampedLeft + maxWidth - menuSize.width,
        _ContextMenuLocation.center =>
          clampedLeft + (maxWidth - menuSize.width) / 2,
      };

      final Offset childPosition = Offset(childLeft, clampedTop);
      final Offset menuPosition = Offset(
        menuLeft,
        clampedTop + childSize.height + _ContextMenuRouteStaticState._kPadding,
      );

      positionChild(_ContextMenuChild.child, childPosition);
      positionChild(_ContextMenuChild.menuSheet, menuPosition);
    } else {
      // Landscape orientation: menu beside child
      final bool menuOnRight =
          contextMenuLocation == _ContextMenuLocation.right;
      final Offset childPosition = menuOnRight
          ? Offset(
              clampedLeft +
                  menuSize.width +
                  _ContextMenuRouteStaticState._kPadding,
              clampedTop,
            )
          : Offset(clampedLeft, clampedTop);
      final Offset menuPosition = menuOnRight
          ? Offset(clampedLeft, clampedTop)
          : Offset(
              clampedLeft +
                  childSize.width +
                  _ContextMenuRouteStaticState._kPadding,
              clampedTop,
            );

      positionChild(_ContextMenuChild.child, childPosition);
      positionChild(_ContextMenuChild.menuSheet, menuPosition);
    }

    // Position top widget above child if it exists
    if (hasTopWidget && topWidgetSize != null) {
      if (orientation == Orientation.portrait) {
        final double topWidgetLeft = switch (contextMenuLocation) {
          _ContextMenuLocation.left => clampedLeft,
          _ContextMenuLocation.right =>
            clampedLeft + maxWidth - topWidgetSize.width,
          _ContextMenuLocation.center =>
            clampedLeft + (maxWidth - topWidgetSize.width) / 2,
        };

        final Offset topWidgetOffset = Offset(
          topWidgetLeft,
          clampedTop -
              topWidgetSize.height -
              _ContextMenuRouteStaticState._kPadding,
        );
        positionChild(_ContextMenuChild.topWidget, topWidgetOffset);
      } else {
        // Landscape: position top widget above child
        final bool menuOnRight =
            contextMenuLocation == _ContextMenuLocation.right;
        final double topWidgetLeft = menuOnRight
            ? clampedLeft +
                  menuSize.width +
                  _ContextMenuRouteStaticState._kPadding
            : clampedLeft;

        final Offset topWidgetOffset = Offset(
          topWidgetLeft,
          clampedTop -
              topWidgetSize.height -
              _ContextMenuRouteStaticState._kPadding,
        );
        positionChild(_ContextMenuChild.topWidget, topWidgetOffset);
      }
    }
  }

  @override
  bool shouldRelayout(_ContextMenuAlignedChildrenDelegate oldDelegate) {
    return oldDelegate.targetRect != targetRect ||
        oldDelegate.screenBounds != screenBounds ||
        oldDelegate.orientation != orientation ||
        oldDelegate.contextMenuLocation != contextMenuLocation ||
        oldDelegate.hasTopWidget != hasTopWidget;
  }
}
