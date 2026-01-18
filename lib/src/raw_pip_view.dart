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
  final Widget? stickyButton;
  final Alignment stickyButtonAlignment;
  final bool freePositioning;
  final double edgePadding;
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
    this.stickyButton,
    this.stickyButtonAlignment = Alignment.topRight,
    this.freePositioning = true,
    this.edgePadding = 16.0,
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
  Offset _currentPosition = Offset.zero;
  Offset _dragOffset = Offset.zero;
  var _isDragging = false;
  var _isFloating = false;
  Widget? _bottomWidgetGhost;
  Map<PIPViewCorner, Offset> _offsets = {};

  Size _screenSize = Size.zero;
  Size _widgetSize = Size.zero;
  EdgeInsets _windowPadding = EdgeInsets.zero;

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
    startRotaionAnimation();
  }

  @override
  void didUpdateWidget(covariant RawPIPView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isFloating) {
      if (widget.topWidget == null || widget.bottomWidget == null) {
        _isFloating = false;
        _bottomWidgetGhost = oldWidget.bottomWidget;
        _toggleFloatingAnimationController.reverse().whenCompleteOrCancel(() {
          if (mounted) {
            setState(() => _bottomWidgetGhost = null);
          }
        });
      }
    } else {
      if (widget.topWidget != null && widget.bottomWidget != null) {
        _isFloating = true;
        if (_offsets.isNotEmpty) {
          _currentPosition = _offsets[_corner] ?? Offset.zero;
        }
        _toggleFloatingAnimationController.forward();
      }
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _toggleFloatingAnimationController.dispose();
    _dragAnimationController.dispose();
    super.dispose();
  }

  void startRotaionAnimation() {
    _rotationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 35),
    )..repeat();

    _rotationAnimation = Tween<double>(begin: 0, end: 2 * 3.1416).animate(
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
    // FIX: Assign these values so _clampToScreenBounds works correctly
    _screenSize = spaceSize;
    _widgetSize = widgetSize;
    _windowPadding = windowPadding;

    _offsets = _calculateOffsets(
      spaceSize: spaceSize,
      widgetSize: widgetSize,
      windowPadding: windowPadding,
    );

    // Initialize current position if not set
    if (_currentPosition == Offset.zero && _offsets.isNotEmpty) {
      _currentPosition = _offsets[_corner] ?? Offset.zero;
    }
  }

  bool _isAnimating() {
    return _toggleFloatingAnimationController.isAnimating ||
        _dragAnimationController.isAnimating;
  }

  // Clamp position to screen boundaries
  Offset _clampToScreenBounds(Offset position) {
    // Safety check - if sizes aren't set yet, return position unchanged
    if (_screenSize == Size.zero || _widgetSize == Size.zero) {
      return position;
    }

    final minX = widget.edgePadding + _windowPadding.left;
    final minY = widget.edgePadding + _windowPadding.top;
    final maxX = _screenSize.width -
        _widgetSize.width -
        widget.edgePadding -
        _windowPadding.right;
    final maxY = _screenSize.height -
        _widgetSize.height -
        widget.edgePadding -
        _windowPadding.bottom;

    // Ensure max is not less than min (edge case for very small screens)
    final clampedX = position.dx.clamp(minX, maxX > minX ? maxX : minX);
    final clampedY = position.dy.clamp(minY, maxY > minY ? maxY : minY);

    return Offset(clampedX, clampedY);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      if (widget.freePositioning) {
        // Free positioning - update current position directly
        _currentPosition = _clampToScreenBounds(
          _currentPosition.translate(details.delta.dx, details.delta.dy),
        );
      } else {
        // Original corner-snapping behavior
        _dragOffset = _dragOffset.translate(
          details.delta.dx,
          details.delta.dy,
        );
      }
    });
  }

  void _onPanCancel() {
    if (!_isDragging) return;
    setState(() {
      _dragAnimationController.value = 0;
      if (!widget.freePositioning) {
        _dragOffset = Offset.zero;
      }
      _isDragging = false;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging) return;

    if (widget.freePositioning) {
      // Free positioning - just stop dragging, position is already set
      setState(() {
        _isDragging = false;
      });
    } else {
      // Original corner-snapping behavior
      final nearestCorner = _calculateNearestCorner(
        offset: _dragOffset,
        offsets: _offsets,
      );
      setState(() {
        _corner = nearestCorner;
        _isDragging = false;
      });
      _dragAnimationController.forward().whenCompleteOrCancel(() {
        _dragAnimationController.value = 0;
        _dragOffset = Offset.zero;
      });
    }
  }

  void _onPanStart(DragStartDetails details) {
    if (_isAnimating()) return;
    setState(() {
      if (!widget.freePositioning) {
        _dragOffset = _offsets[_corner]!;
      }
      _isDragging = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    var windowPadding = mediaQuery.padding;
    if (widget.avoidKeyboard) {
      windowPadding += mediaQuery.viewInsets;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final bottomWidget = widget.bottomWidget ?? _bottomWidgetGhost;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        double? floatingWidth = widget.floatingWidth;
        double? floatingHeight = widget.floatingHeight;
        if (floatingWidth == null && floatingHeight != null) {
          floatingWidth = width / height * floatingHeight;
        }
        floatingWidth ??= 100.0;
        if (floatingHeight == null) {
          floatingHeight = height / width * floatingWidth;
        }

        final floatingWidgetSize = Size(floatingWidth, floatingHeight);
        final fullWidgetSize = Size(width, height);

        // This now properly updates _screenSize, _widgetSize, and _windowPadding
        _updateCornersOffsets(
          spaceSize: fullWidgetSize,
          widgetSize: floatingWidgetSize,
          windowPadding: windowPadding,
        );

        final calculatedOffset = _offsets[_corner];

        // BoxFit.cover
        final widthRatio = floatingWidth / width;
        final heightRatio = floatingHeight / height;
        final scaledDownScale = widthRatio > heightRatio
            ? floatingWidgetSize.width / fullWidgetSize.width
            : floatingWidgetSize.height / fullWidgetSize.height;

        return Stack(
          children: <Widget>[
            if (bottomWidget != null) bottomWidget,
            if (widget.topWidget != null)
              AnimatedBuilder(
                animation: Listenable.merge([
                  _toggleFloatingAnimationController,
                  _dragAnimationController,
                ]),
                builder: (context, child) {
                  final animationCurve = CurveTween(
                    curve: Curves.easeInOutQuad,
                  );
                  final dragAnimationValue = animationCurve.transform(
                    _dragAnimationController.value,
                  );
                  final toggleFloatingAnimationValue = animationCurve.transform(
                    _toggleFloatingAnimationController.value,
                  );

                  // Calculate floating offset based on positioning mode
                  Offset floatingOffset;

                  if (widget.freePositioning) {
                    // Free positioning mode
                    if (_isFloating) {
                      floatingOffset = _currentPosition;
                    } else {
                      // Transitioning to floating - animate from full screen to initial position
                      floatingOffset = Tween<Offset>(
                        begin: Offset.zero,
                        end: _currentPosition,
                      ).transform(toggleFloatingAnimationValue);
                    }
                  } else {
                    // Original corner-snapping mode
                    floatingOffset = _isDragging
                        ? _dragOffset
                        : Tween<Offset>(
                            begin: _dragOffset,
                            end: calculatedOffset,
                          ).transform(_dragAnimationController.isAnimating
                            ? dragAnimationValue
                            : toggleFloatingAnimationValue);
                  }

                  final borderRadius = Tween<double>(
                    begin: 0,
                    end: 10,
                  ).transform(toggleFloatingAnimationValue);
                  final currentWidth = Tween<double>(
                    begin: fullWidgetSize.width,
                    end: floatingWidgetSize.width,
                  ).transform(toggleFloatingAnimationValue);
                  final currentHeight = Tween<double>(
                    begin: fullWidgetSize.height,
                    end: floatingWidgetSize.height,
                  ).transform(toggleFloatingAnimationValue);
                  final scale = Tween<double>(
                    begin: 1,
                    end: scaledDownScale,
                  ).transform(toggleFloatingAnimationValue);

                  return Positioned(
                    left: floatingOffset.dx,
                    top: floatingOffset.dy,
                    child: GestureDetector(
                      onPanStart: _isFloating ? _onPanStart : null,
                      onPanUpdate: _isFloating ? _onPanUpdate : null,
                      onPanCancel: _isFloating ? _onPanCancel : null,
                      onPanEnd: _isFloating ? _onPanEnd : null,
                      onTap: widget.onTapTopWidget,
                      child: SizedBox(
                        width: currentWidth,
                        height: currentHeight,
                        child: Stack(
                          children: [
                            // The rotating PIP view content
                            Positioned.fill(
                              child: Material(
                                borderRadius:
                                    BorderRadius.circular(borderRadius),
                                color: Colors.transparent,
                                child: _isFloating
                                    ? AnimatedBuilder(
                                        animation: _rotationAnimation,
                                        builder: (context, child) {
                                          return Transform.rotate(
                                            angle: _rotationAnimation.value,
                                            child: child,
                                          );
                                        },
                                        child: widget.pipViewWidget,
                                      )
                                    : Container(
                                        clipBehavior: Clip.antiAlias,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                              borderRadius),
                                        ),
                                        width: currentWidth,
                                        height: currentHeight,
                                        child: Transform.scale(
                                          scale: scale,
                                          child: OverflowBox(
                                            maxHeight: fullWidgetSize.height,
                                            maxWidth: fullWidgetSize.width,
                                            child: child,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            // The sticky button that doesn't rotate
                            if (_isFloating && widget.stickyButton != null)
                              Align(
                                alignment: widget.stickyButtonAlignment,
                                child: widget.stickyButton!,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                child: _isFloating
                    ? AnimatedBuilder(
                        animation: _rotationAnimation,
                        builder: (context, child) {
                          return Transform.rotate(
                            angle: _rotationAnimation.value,
                            child: child,
                          );
                        },
                        child: widget.pipViewWidget,
                      )
                    : widget.topWidget,
              ),
          ],
        );
      },
    );
  }
}

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

  _CornerDistance({
    required this.corner,
    required this.distance,
  });
}

PIPViewCorner _calculateNearestCorner({
  required Offset offset,
  required Map<PIPViewCorner, Offset> offsets,
}) {
  _CornerDistance calculateDistance(PIPViewCorner corner) {
    final distance = offsets[corner]!
        .translate(
          -offset.dx,
          -offset.dy,
        )
        .distanceSquared;
    return _CornerDistance(
      corner: corner,
      distance: distance,
    );
  }

  final distances = PIPViewCorner.values.map(calculateDistance).toList();
  distances.sort((cd0, cd1) => cd0.distance.compareTo(cd1.distance));
  return distances.first.corner;
}

Map<PIPViewCorner, Offset> _calculateOffsets({
  required Size spaceSize,
  required Size widgetSize,
  required EdgeInsets windowPadding,
}) {
  Offset getOffsetForCorner(PIPViewCorner corner) {
    final spacing = 16.0;
    final left = spacing + windowPadding.left;
    final top = spacing + windowPadding.top;
    final right =
        spaceSize.width - widgetSize.width - windowPadding.right - spacing;
    final bottom =
        spaceSize.height - widgetSize.height - windowPadding.bottom - spacing;

    switch (corner) {
      case PIPViewCorner.topLeft:
        return Offset(left, top);
      case PIPViewCorner.topRight:
        return Offset(right, top);
      case PIPViewCorner.bottomLeft:
        return Offset(left, bottom);
      case PIPViewCorner.bottomRight:
        return Offset(right, bottom);
      case PIPViewCorner.topCenter:
        return Offset((spaceSize.width - widgetSize.width) / 2, top);
      case PIPViewCorner.bottomCenter:
        return Offset((spaceSize.width - widgetSize.width) / 2, bottom);
      case PIPViewCorner.leftCenter:
        return Offset(left, (spaceSize.height - widgetSize.height) / 2);
      case PIPViewCorner.rightCenter:
        return Offset(right, (spaceSize.height - widgetSize.height) / 2);
      default:
        throw UnimplementedError();
    }
  }

  final corners = PIPViewCorner.values;
  final Map<PIPViewCorner, Offset> offsets = {};
  for (final corner in corners) {
    offsets[corner] = getOffsetForCorner(corner);
  }

  return offsets;
}
