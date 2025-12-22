class PIPViewState extends State<PIPView>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin
    implements PIPController {

  final PIPNavigationService _navigationService = PIPNavigationService();
  Widget? _bottomWidget;
  bool _isPIPActive = false;

  @override
  bool get wantKeepAlive => true; // 👈 KEEP ALIVE

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
    super.build(context); // 👈 REQUIRED

    final isFloating = _bottomWidget != null;

    return WillPopScope(
      onWillPop: _onWillPop,
      child: RawPIPView(
        avoidKeyboard: widget.avoidKeyboard,
        pipViewWidget: widget.pipViewWidget,
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
