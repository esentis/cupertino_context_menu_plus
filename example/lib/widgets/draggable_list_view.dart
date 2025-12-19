import 'package:flutter/cupertino.dart';

/// A draggable list view that reveals content on horizontal drag.
///
/// Wraps any scrollable widget and provides drag offset and animation
/// to child widgets through a builder callback.
class DraggableListView extends StatefulWidget {
  const DraggableListView({
    super.key,
    required this.builder,
    this.maxDragDistance = 80.0,
    this.animationDuration = const Duration(milliseconds: 300),
    this.animationCurve = Curves.easeOutCubic,
  });

  /// Builder function that provides drag state to build the list content
  final Widget Function(
    BuildContext context,
    double dragOffset,
    Animation<double> slideAnimation,
  ) builder;

  /// Maximum distance the user can drag (in pixels)
  final double maxDragDistance;

  /// Duration of the snap-back animation
  final Duration animationDuration;

  /// Curve for the snap-back animation
  final Curve animationCurve;

  @override
  State<DraggableListView> createState() => _DraggableListViewState();
}

class _DraggableListViewState extends State<DraggableListView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideController;
  late final CurvedAnimation _slideAnimation;
  double _dragOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _slideController =
        AnimationController(vsync: this, duration: widget.animationDuration)
          ..addListener(() {
            setState(() {});
          });
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: widget.animationCurve,
    );
  }

  @override
  void dispose() {
    _slideAnimation.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _handleHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
      _dragOffset = _dragOffset.clamp(-widget.maxDragDistance, 0.0);
    });
  }

  void _handleHorizontalDragEnd(DragEndDetails details) {
    _slideController.reset();
    _slideController.forward().then((_) {
      if (mounted) {
        setState(() {
          _dragOffset = 0.0;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragUpdate: _handleHorizontalDragUpdate,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: widget.builder(context, _dragOffset, _slideAnimation),
    );
  }
}
