import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';
import '../../app/theme/fnc_fonts.dart';
import '../i18n/locale_loader.dart';
import '../i18n/translated_texts.dart';
import '../state/locale_controller.dart';
import 'animated_iagents_mark.dart';

/// Mantiene el contenido visible durante una espera y coloca por encima el
/// cargador de marca. El desenfoque conserva el contexto sin dejar que el
/// usuario interactúe con datos que todavía se están actualizando.
class IAgentsLoadingOverlay extends StatefulWidget {
  const IAgentsLoadingOverlay({
    required this.loading,
    required this.localeController,
    required this.child,
    this.logoSize = 84,
    this.blurSigma = 7,
    this.overlayOpacity = 0.72,
    this.showDelay = const Duration(milliseconds: 120),
    this.minimumVisibleDuration = const Duration(milliseconds: 400),
    this.messages,
    super.key,
  });

  final bool loading;
  final LocaleController localeController;
  final Widget child;
  final double logoSize;
  final double blurSigma;
  final double overlayOpacity;
  final Duration showDelay;
  final Duration minimumVisibleDuration;
  final List<String>? messages;

  @override
  State<IAgentsLoadingOverlay> createState() => _IAgentsLoadingOverlayState();
}

class _IAgentsLoadingOverlayState extends State<IAgentsLoadingOverlay> {
  Timer? _showTimer;
  Timer? _hideTimer;
  DateTime? _visibleSince;
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _syncVisibility();
  }

  @override
  void didUpdateWidget(IAgentsLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.loading != widget.loading ||
        oldWidget.showDelay != widget.showDelay ||
        oldWidget.minimumVisibleDuration != widget.minimumVisibleDuration) {
      _syncVisibility();
    }
  }

  void _syncVisibility() {
    if (widget.loading) {
      _hideTimer?.cancel();
      if (_visible || _showTimer?.isActive == true) return;
      if (widget.showDelay == Duration.zero) {
        _show();
      } else {
        _showTimer = Timer(widget.showDelay, _show);
      }
      return;
    }

    _showTimer?.cancel();
    if (!_visible) return;
    final elapsed = DateTime.now().difference(_visibleSince!);
    final remaining = widget.minimumVisibleDuration - elapsed;
    if (remaining <= Duration.zero) {
      _hide();
    } else {
      _hideTimer = Timer(remaining, _hide);
    }
  }

  void _show() {
    if (!mounted || !widget.loading || _visible) return;
    setState(() {
      _visible = true;
      _visibleSince = DateTime.now();
    });
  }

  void _hide() {
    if (!mounted || widget.loading || !_visible) return;
    setState(() {
      _visible = false;
      _visibleSince = null;
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = IgnorePointer(
      key: const Key('iagents-loading-content'),
      ignoring: widget.loading,
      child: ExcludeSemantics(excluding: _visible, child: widget.child),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        // Se mantiene siempre el mismo padre para no desmontar el contenido
        // al activar el blur (un FutureBuilder volvería fugazmente a waiting).
        ImageFiltered(
          imageFilter: ImageFilter.blur(
            sigmaX: _visible ? widget.blurSigma : 0,
            sigmaY: _visible ? widget.blurSigma : 0,
          ),
          child: content,
        ),
        if (_visible)
          Positioned.fill(
            key: const Key('iagents-loading-overlay'),
            child: ColoredBox(
              color: Theme.of(context).scaffoldBackgroundColor
                  .withValues(alpha: widget.overlayOpacity),
              child: SafeArea(
                child: Center(
                  child: IAgentsLoadingIndicator(
                    localeController: widget.localeController,
                    messages: widget.messages,
                    logoSize: widget.logoSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Indicador compartido para esperas que ocupan una sección o una pantalla.
/// Combina el icono animado de iAgents Hub con mensajes elegidos al azar en el
/// idioma activo, sin repetir dos veces seguidas. Los espacios pequeños usan
/// [IAgentsLoadingMark].
class IAgentsLoadingIndicator extends StatefulWidget {
  const IAgentsLoadingIndicator({
    required this.localeController,
    this.messages,
    this.logoSize = 84,
    this.messageInterval = const Duration(milliseconds: 1600),
    this.maxMessageWidth = 320,
    this.translationLoader = LocaleLoader.load,
    this.random,
    super.key,
  });

  final LocaleController localeController;
  final List<String>? messages;
  final double logoSize;
  final Duration messageInterval;
  final double maxMessageWidth;
  final TranslationBundleLoader translationLoader;

  /// Generador inyectable para que la selección aleatoria sea comprobable.
  final Random? random;

  @override
  State<IAgentsLoadingIndicator> createState() =>
      _IAgentsLoadingIndicatorState();
}

class _IAgentsLoadingIndicatorState extends State<IAgentsLoadingIndicator> {
  late TranslatedTexts _texts;
  late Random _random;
  Timer? _messageTimer;
  int _messageIndex = 0;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _random = widget.random ?? Random();
    _bindTexts();
    _startMessageTimer();
  }

  void _bindTexts() {
    _texts = TranslatedTexts(
      localeController: widget.localeController,
      namespace: 'common',
      loader: widget.translationLoader,
    )..addListener(_onTextsChanged);
  }

  void _onTextsChanged() {
    if (!mounted) return;
    setState(() => _messageIndex = 0);
  }

  void _startMessageTimer() {
    _messageTimer?.cancel();
    _messageTimer = Timer.periodic(widget.messageInterval, (_) {
      if (!mounted || _reduceMotion) return;
      final messages = _messages;
      if (messages.length < 2) return;
      setState(() {
        final currentIndex = _messageIndex % messages.length;
        final candidate = _random.nextInt(messages.length - 1);
        _messageIndex = candidate >= currentIndex ? candidate + 1 : candidate;
      });
    });
  }

  List<String> get _messages {
    final customMessages = widget.messages;
    if (customMessages != null && customMessages.isNotEmpty) {
      return customMessages;
    }
    final loadedMessages = _texts.map('loading_messages');
    final messages = loadedMessages.isNotEmpty
        ? loadedMessages
        : LocaleLoader.cachedMap(
            languageCode: widget.localeController.languageCode,
            namespace: 'common',
            path: 'loading_messages',
          );
    return messages.values.toList(growable: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) _messageIndex = 0;
  }

  @override
  void didUpdateWidget(IAgentsLoadingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.random != widget.random) {
      _random = widget.random ?? Random();
    }
    if (oldWidget.localeController != widget.localeController ||
        oldWidget.translationLoader != widget.translationLoader) {
      _texts
        ..removeListener(_onTextsChanged)
        ..dispose();
      _bindTexts();
      _messageIndex = 0;
    }
    if (oldWidget.messageInterval != widget.messageInterval) {
      _startMessageTimer();
    }
    if (oldWidget.messages != widget.messages) _messageIndex = 0;
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _texts
      ..removeListener(_onTextsChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messages = _messages;
    final safeIndex = messages.isEmpty ? 0 : _messageIndex % messages.length;
    final message = messages.isEmpty ? '' : messages[safeIndex];

    return Semantics(
      key: const Key('iagents-loading-indicator'),
      container: true,
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: widget.logoSize,
              child: IAgentsLoadingMark(
                size: widget.logoSize,
                maxSize: widget.logoSize,
              ),
            ),
            const SizedBox(height: 18),
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: widget.maxMessageWidth),
              child: SizedBox(
                height: 28,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: _reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 280),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.18),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    ),
                    child: Text(
                      message,
                      key: ValueKey(message),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FncFonts.code.copyWith(
                        color: FncColors.textMuted(context),
                        fontSize: FncFonts.size14,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
