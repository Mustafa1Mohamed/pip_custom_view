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
  final Widget?
      frameWidget; // NEW: Frame widget that wraps the rotating content

  const RawPIPView({
    Key? key,
    this.initialCorner = PIPViewCorner.rightTop,
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
    this.frameWidget, // NEW
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
      duration: Duration(seconds: 5),
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
    _screenSize = spaceSize;
    _widgetSize = widgetSize;
    _windowPadding = windowPadding;

    _offsets = _calculateOffsets(
      spaceSize: spaceSize,
      widgetSize: widgetSize,
      windowPadding: windowPadding,
    );

    if (_currentPosition == Offset.zero && _offsets.isNotEmpty) {
      _currentPosition = _offsets[_corner] ?? Offset.zero;
    }
  }

  bool _isAnimating() {
    return _toggleFloatingAnimationController.isAnimating ||
        _dragAnimationController.isAnimating;
  }

  Offset _clampToScreenBounds(Offset position) {
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

    final clampedX = position.dx.clamp(minX, maxX > minX ? maxX : minX);
    final clampedY = position.dy.clamp(minY, maxY > minY ? maxY : minY);

    return Offset(clampedX, clampedY);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    setState(() {
      if (widget.freePositioning) {
        _currentPosition = _clampToScreenBounds(
          _currentPosition.translate(details.delta.dx, details.delta.dy),
        );
      } else {
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
      setState(() {
        _isDragging = false;
      });
    } else {
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

        _updateCornersOffsets(
          spaceSize: fullWidgetSize,
          widgetSize: floatingWidgetSize,
          windowPadding: windowPadding,
        );

        final calculatedOffset = _offsets[_corner];

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

                  Offset floatingOffset;

                  if (widget.freePositioning) {
                    if (_isFloating) {
                      floatingOffset = _currentPosition;
                    } else {
                      floatingOffset = Tween<Offset>(
                        begin: Offset.zero,
                        end: _currentPosition,
                      ).transform(toggleFloatingAnimationValue);
                    }
                  } else {
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
                          clipBehavior: Clip.none,
                          children: [
                            // Layer 1: The rotating PIP view content (bottom layer)
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

                            // Layer 2: The frame widget (above rotating content, doesn't rotate)
                            if (_isFloating && widget.frameWidget != null)
                              Positioned(
                                left: 0,
                                top: 0,
                                right: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  // Allow touches to pass through to the content below
                                  ignoring: true,
                                  child: OverflowBox(
                                    maxWidth: double.infinity,
                                      maxHeight: double.infinity,
                                      alignment: Alignment.center,
                                    child: widget.frameWidget!),
                                ),
                              ),

                            // Layer 3: The sticky button (top layer, doesn't rotate)
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

// Updated enum with 16 positions (4 columns x 4 rows)
enum PIPViewCorner {
  // Left column (4 points)
  leftTop,
  leftUpperMiddle,
  leftLowerMiddle,
  leftBottom,

  // Center-left column (4 points)
  centerLeftTop,
  centerLeftUpperMiddle,
  centerLeftLowerMiddle,
  centerLeftBottom,

  // Center-right column (4 points)
  centerRightTop,
  centerRightUpperMiddle,
  centerRightLowerMiddle,
  centerRightBottom,

  // Right column (4 points)
  rightTop,
  rightUpperMiddle,
  rightLowerMiddle,
  rightBottom,
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

    // Calculate horizontal positions (4 columns)
    final left = spacing + windowPadding.left;
    final right =
        spaceSize.width - widgetSize.width - windowPadding.right - spacing;
    final totalHorizontalSpace = right - left;
    final centerLeft = left + totalHorizontalSpace / 3;
    final centerRight = left + (totalHorizontalSpace * 2) / 3;

    // Calculate vertical positions (4 rows)
    final top = spacing + windowPadding.top;
    final bottom =
        spaceSize.height - widgetSize.height - windowPadding.bottom - spacing;
    final totalVerticalSpace = bottom - top;
    final upperMiddle = top + totalVerticalSpace / 3;
    final lowerMiddle = top + (totalVerticalSpace * 2) / 3;

    switch (corner) {
      // Left column
      case PIPViewCorner.leftTop:
        return Offset(left, top);
      case PIPViewCorner.leftUpperMiddle:
        return Offset(left, upperMiddle);
      case PIPViewCorner.leftLowerMiddle:
        return Offset(left, lowerMiddle);
      case PIPViewCorner.leftBottom:
        return Offset(left, bottom);

      // Center-left column
      case PIPViewCorner.centerLeftTop:
        return Offset(centerLeft, top);
      case PIPViewCorner.centerLeftUpperMiddle:
        return Offset(centerLeft, upperMiddle);
      case PIPViewCorner.centerLeftLowerMiddle:
        return Offset(centerLeft, lowerMiddle);
      case PIPViewCorner.centerLeftBottom:
        return Offset(centerLeft, bottom);

      // Center-right column
      case PIPViewCorner.centerRightTop:
        return Offset(centerRight, top);
      case PIPViewCorner.centerRightUpperMiddle:
        return Offset(centerRight, upperMiddle);
      case PIPViewCorner.centerRightLowerMiddle:
        return Offset(centerRight, lowerMiddle);
      case PIPViewCorner.centerRightBottom:
        return Offset(centerRight, bottom);

      // Right column
      case PIPViewCorner.rightTop:
        return Offset(right, top);
      case PIPViewCorner.rightUpperMiddle:
        return Offset(right, upperMiddle);
      case PIPViewCorner.rightLowerMiddle:
        return Offset(right, lowerMiddle);
      case PIPViewCorner.rightBottom:
        return Offset(right, bottom);
    }
  }

  final corners = PIPViewCorner.values;
  final Map<PIPViewCorner, Offset> offsets = {};
  for (final corner in corners) {
    offsets[corner] = getOffsetForCorner(corner);
  }

  return offsets;
}
