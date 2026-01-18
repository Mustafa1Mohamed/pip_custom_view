import 'package:flutter/material.dart';
import 'constants.dart';

class RawPIPView extends StatefulWidget {
  final PIPViewCorner initialCorner;
  final double? floatingWidth;
  final double? floatingHeight;
  final bool avoidKeyboard;
  final Widget? topWidget;
  final Widget? bottomWidget;
  final Widget pipViewWidget;
  final Widget? closeButton;
  final void Function()? onTapTopWidget;

  const RawPIPView({
    Key? key,
    this.initialCorner = PIPViewCorner.topRight,
    this.floatingWidth,
    this.floatingHeight,
    this.avoidKeyboard = true,
    this.topWidget,
    this.bottomWidget,
    this.onTapTopWidget,
    required this.pipViewWidget,
    this.closeButton,
  }) : super(key: key);

  @override
  RawPIPViewState createState() => RawPIPViewState();
}

class RawPIPViewState extends State<RawPIPView> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late Animation<double> _rotationAnimation;

  late final AnimationController _toggleFloatingAnimationController;
  late final AnimationController _dragAnimationController;

  late PIPViewCorner _corner;
  Offset _dragOffset = Offset.zero;
  bool _isDragging = false;
  bool _isFloating = false;

  Widget? _bottomWidgetGhost;
  Map<PIPViewCorner, Offset> _offsets = {};

  @override
  void initState() {
    super.initState();
    _corner = widget.initialCorner;

    _toggleFloatingAnimationController = AnimationController(
      duration: defaultAnimationDuration,
      vsync: this,
    );

    _dragAnimationController = AnimationController(
      duration: defaultAnimationDuration,
      vsync: this,
    );

    _startRotationAnimation();
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _toggleFloatingAnimationController.dispose();
    _dragAnimationController.dispose();
    super.dispose();
  }

  void _startRotationAnimation() {
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 35),
    )..repeat();

    _rotationAnimation = Tween<double>(
      begin: 0,
      end: 2 * 3.1415926535,
    ).animate(
      CurvedAnimation(
        parent: _rotationController,
        curve: Curves.linear,
      ),
    );
  }

  void _updateCornersOffsets({
    required Size spaceSize,
    required Size widgetSize,
    required EdgeInsets windowPadding,
  }) {
    _offsets = _calculateOffsets(
      spaceSize: spaceSize,
      widgetSize: widgetSize,
      windowPadding: windowPadding,
    );
  }

  bool _isAnimating() =>
      _toggleFloatingAnimationController.isAnimating ||
      _dragAnimationController.isAnimating;

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating()) return;
    setState(() {
      _dragOffset = _offsets[_corner]!;
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
      _dragOffset = Offset.zero;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    final nearestCorner = _calculateNearestCorner(
      offset: _dragOffset,
      offsets: _offsets,
    );

    setState(() {
      _corner = nearestCorner;
      _isDragging = false;
    });

    _dragAnimationController.forward().whenComplete(() {
      _dragAnimationController.value = 0;
      _dragOffset = Offset.zero;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    EdgeInsets windowPadding = mediaQuery.padding;
    if (widget.avoidKeyboard) {
      windowPadding += mediaQuery.viewInsets;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomWidget = widget.bottomWidget ?? _bottomWidgetGhost;

        final fullSize = Size(
          constraints.maxWidth,
          constraints.maxHeight,
        );

        double floatingWidth = widget.floatingWidth ?? 100;
        double floatingHeight = widget.floatingHeight ?? floatingWidth;

        final floatingSize = Size(floatingWidth, floatingHeight);

        _updateCornersOffsets(
          spaceSize: fullSize,
          widgetSize: floatingSize,
          windowPadding: windowPadding,
        );

        final calculatedOffset = _offsets[_corner]!;

        return Stack(
          children: [
            if (bottomWidget != null) bottomWidget,
            if (widget.topWidget != null)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _toggleFloatingAnimationController,
                  _dragAnimationController,
                ]),
                builder: (context, child) {
                  final curve = Curves.easeInOutQuad;

                  final toggleValue = curve.transform(
                    _toggleFloatingAnimationController.value,
                  );

                  final dragValue = curve.transform(
                    _dragAnimationController.value,
                  );

                  final offset = _isDragging
                      ? _dragOffset
                      : Tween<Offset>(
                          begin: _dragOffset,
                          end: calculatedOffset,
                        ).transform(
                          _dragAnimationController.isAnimating
                              ? dragValue
                              : toggleValue,
                        );

                  // Inside RawPIPView build method...
                  return Positioned(
                    left: offset.dx,
                    top: offset.dy,
                    child: GestureDetector(
                      onPanStart: _isFloating ? _onPanStart : null,
                      // ... other pan handlers
                      child: SizedBox(
                        width: floatingSize.width,
                        height: floatingSize.height,
                        child: Stack(
                          clipBehavior: Clip
                              .none, // Allows button to sit slightly outside if needed
                          children: [
                            // 1. THE ROTATING CONTENT
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _rotationAnimation,
                                builder: (context, child) {
                                  return Transform.rotate(
                                    angle: _rotationAnimation.value,
                                    child: child,
                                  );
                                },
                                child: widget.pipViewWidget,
                              ),
                            ),

                            
                            if (_isFloating)
                              Positioned(
                                right: -10,
                                top: -10,
                                child: widget.closeButton ?? Container(),
                              ),

                            // if (_isFloating && widget.closeButton != null)
                            //   Align(
                            //     alignment: Alignment.bottomCenter,
                            //     child: widget.closeButton,
                            //   ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: widget.topWidget,
              ),
          ],
        );
      },
    );
  }
}

/* -------------------------------------------------------------------------- */
/*                                  HELPERS                                   */
/* -------------------------------------------------------------------------- */

enum PIPViewCorner {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  topCenter,
  bottomCenter,
  leftCenter,
  rightCenter,
}

class _CornerDistance {
  final PIPViewCorner corner;
  final double distance;
  _CornerDistance({required this.corner, required this.distance});
}

PIPViewCorner _calculateNearestCorner({
  required Offset offset,
  required Map<PIPViewCorner, Offset> offsets,
}) {
  final distances = offsets.entries
      .map(
        (e) => _CornerDistance(
          corner: e.key,
          distance: (e.value - offset).distanceSquared,
        ),
      )
      .toList();

  distances.sort((a, b) => a.distance.compareTo(b.distance));
  return distances.first.corner;
}

Map<PIPViewCorner, Offset> _calculateOffsets({
  required Size spaceSize,
  required Size widgetSize,
  required EdgeInsets windowPadding,
}) {
  const spacing = 16.0;

  final left = spacing + windowPadding.left;
  final top = spacing + windowPadding.top;
  final right = spaceSize.width - widgetSize.width - spacing;
  final bottom = spaceSize.height - widgetSize.height - spacing;

  return {
    PIPViewCorner.topLeft: Offset(left, top),
    PIPViewCorner.topRight: Offset(right, top),
    PIPViewCorner.bottomLeft: Offset(left, bottom),
    PIPViewCorner.bottomRight: Offset(right, bottom),
    PIPViewCorner.topCenter:
        Offset((spaceSize.width - widgetSize.width) / 2, top),
    PIPViewCorner.bottomCenter:
        Offset((spaceSize.width - widgetSize.width) / 2, bottom),
    PIPViewCorner.leftCenter:
        Offset(left, (spaceSize.height - widgetSize.height) / 2),
    PIPViewCorner.rightCenter:
        Offset(right, (spaceSize.height - widgetSize.height) / 2),
  };
}
