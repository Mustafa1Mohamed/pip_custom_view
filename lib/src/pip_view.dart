// ============================================================================
import 'package:flutter/material.dart';
import 'dismiss_keyboard.dart';
import 'helpers/pip_controllers.dart';
import 'helpers/pip_navigation_services.dart';
import 'raw_pip_view.dart';

enum PipViewState { expanded, floating }

class PIPView extends StatefulWidget {
  final PIPViewCorner initialCorner;
  final double? floatingWidth;
  final double? floatingHeight;
  final bool avoidKeyboard;
  final Widget pipViewWidget;
  final Widget Function(BuildContext context, bool isFloating) builder;
  final GlobalKey<NavigatorState>? parentNavigatorKey;
  final Route<dynamic> Function(RouteSettings) routes;
  final Widget? closeButton;
  final Alignment closeButtonAlignment;

  const PIPView({
    Key? key,
    required this.builder,
    required this.pipViewWidget,
    this.initialCorner = PIPViewCorner.topRight,
    this.floatingWidth,
    this.floatingHeight,
    this.avoidKeyboard = true,
    this.parentNavigatorKey,
    required this.routes,
    this.closeButton,
    this.closeButtonAlignment = Alignment.topRight,
  }) : super(key: key);

  @override
  PIPViewState createState() => PIPViewState();

  static PIPController? of(BuildContext context) {
    return context.findAncestorStateOfType<PIPViewState>();
  }
}

class PIPViewState extends State<PIPView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin
    implements PIPController {
  final PIPNavigationService _navigationService = PIPNavigationService();
  Widget? _bottomWidget;
  bool _isPIPActive = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void presentBelow(Widget widget) {
    setState(() {
      _bottomWidget = widget;
      _isPIPActive = true;
    });
  }

  @override
  void stopFloating() {
    setState(() {
      _bottomWidget = null;
      _isPIPActive = false;
    });
  }

  @override
  bool get isPIPActive => _isPIPActive;

  Future<bool> _onWillPop() async {
    if (_bottomWidget != null) {
      final popped = await _navigationService.maybePop();
      if (popped) return false;
      stopFloating();
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final isFloating = _bottomWidget != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: RawPIPView(
        avoidKeyboard: widget.avoidKeyboard,
        pipViewWidget: widget.pipViewWidget,
        closeButton: widget.closeButton, // ✅ Pass to RawPIPView
        bottomWidget: isFloating
            ? Navigator(
                key: _navigationService.navigatorKey,
                onGenerateRoute: (settings) {
                  if (settings.name == '/') {
                    return MaterialPageRoute(
                      builder: (context) => _bottomWidget!,
                    );
                  } else {
                    return widget.routes(settings);
                  }
                },
              )
            : null,
        onTapTopWidget: isFloating ? stopFloating : null,
        topWidget: Builder(
          builder: (context) => AbsorbPointer(
            absorbing: isFloating,
            child: widget.builder(context, isFloating),
          ),
        ),
        floatingHeight: widget.floatingHeight,
        floatingWidth: widget.floatingWidth,
        initialCorner: widget.initialCorner,
      ),
    );
  }
}
