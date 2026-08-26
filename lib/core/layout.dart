import 'package:flutter/material.dart';

import 'telegram/telegram_bridge.dart';

class TelegramScope extends StatelessWidget {
  final Widget child;

  const TelegramScope({super.key, required this.child});

  static TelegramMetrics of(BuildContext context) {
    final inherited =
        context.dependOnInheritedWidgetOfExactType<_TelegramMetricsInherited>();
    return inherited?.metrics ??
        TelegramMetrics(
          isAvailable: false,
          isExpanded: true,
          viewportHeight: MediaQuery.sizeOf(context).height,
          viewportStableHeight: MediaQuery.sizeOf(context).height,
          safeArea: MediaQuery.paddingOf(context),
          contentSafeArea: MediaQuery.paddingOf(context),
          platform: 'preview',
        );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TelegramBridge.instance,
      builder: (context, _) {
        final size = MediaQuery.sizeOf(context);
        final padding = MediaQuery.paddingOf(context);
        final metrics = TelegramBridge.instance.metricsFor(size, padding);
        return _TelegramMetricsInherited(
          metrics: metrics,
          child: child,
        );
      },
    );
  }
}

class _TelegramMetricsInherited extends InheritedWidget {
  final TelegramMetrics metrics;

  const _TelegramMetricsInherited({
    required this.metrics,
    required super.child,
  });

  @override
  bool updateShouldNotify(_TelegramMetricsInherited oldWidget) {
    return oldWidget.metrics.viewportHeight != metrics.viewportHeight ||
        oldWidget.metrics.viewportStableHeight !=
            metrics.viewportStableHeight ||
        oldWidget.metrics.isExpanded != metrics.isExpanded ||
        oldWidget.metrics.safeArea != metrics.safeArea ||
        oldWidget.metrics.contentSafeArea != metrics.contentSafeArea;
  }
}

/// Layout tokens tuned for Telegram Mini Apps:
/// collapsed/expanded viewport, desktop sidebar (~384px), and iPhone widths.
class TgLayout {
  TgLayout._();

  static const double maxContentWidth = 480;
  static const double navHeight = 60;
  static const double navGap = 10;
  static const double compactNavHeight = 52;

  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 380;

  static bool isNarrow(BuildContext context) =>
      MediaQuery.sizeOf(context).width < 340;

  static bool isShort(BuildContext context) {
    final metrics = TelegramScope.of(context);
    final height = metrics.viewportStableHeight > 0
        ? metrics.viewportStableHeight
        : MediaQuery.sizeOf(context).height;
    return height < 600;
  }

  static double pagePad(BuildContext context) => isCompact(context) ? 12 : 16;

  static double navBarHeight(BuildContext context) =>
      isNarrow(context) || isShort(context) ? compactNavHeight : navHeight;

  static double bottomScrollPadding(
    BuildContext context, {
    bool hasNav = true,
  }) {
    final chrome = TelegramScope.of(context).chromePadding.bottom;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final nav = hasNav ? navBarHeight(context) + navGap + 8 : 16;
    return chrome + nav + keyboard;
  }

  static EdgeInsets pageInsets(
    BuildContext context, {
    bool hasNav = true,
    bool includeTop = true,
  }) {
    final metrics = TelegramScope.of(context);
    final pad = pagePad(context);
    return EdgeInsets.fromLTRB(
      pad + metrics.chromePadding.left,
      includeTop ? 12 + metrics.chromePadding.top : 8,
      pad + metrics.chromePadding.right,
      bottomScrollPadding(context, hasNav: hasNav),
    );
  }
}

class TgContent extends StatelessWidget {
  final Widget child;
  final bool hasNav;
  final bool includeTop;

  const TgContent({
    super.key,
    required this.child,
    this.hasNav = true,
    this.includeTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: TgLayout.maxContentWidth),
        child: Padding(
          padding: TgLayout.pageInsets(
            context,
            hasNav: hasNav,
            includeTop: includeTop,
          ),
          child: child,
        ),
      ),
    );
  }
}

class TgScrollView extends StatelessWidget {
  final List<Widget> children;
  final bool hasNav;
  final CrossAxisAlignment crossAxisAlignment;

  const TgScrollView({
    super.key,
    required this.children,
    this.hasNav = true,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: TgContent(
        hasNav: hasNav,
        child: Column(
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        ),
      ),
    );
  }
}

class TgSubScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final bool resizeToAvoidBottomInset;

  const TgSubScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    final compact = TgLayout.isCompact(context);
    return Scaffold(
      backgroundColor: const Color(0xFF07080A),
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: AppBar(
        toolbarHeight: compact ? 48 : 52,
        leadingWidth: 44,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 18),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: actions,
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: TgLayout.maxContentWidth),
          child: body,
        ),
      ),
    );
  }
}
