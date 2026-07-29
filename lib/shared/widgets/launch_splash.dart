import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_client.dart';
import '../../features/auth/repositories/auth_repository.dart';
import '../state/backend_controller.dart';
import '../state/boot_platform_cache.dart';

class LaunchSplash extends StatefulWidget {
  const LaunchSplash({required this.backendController, required this.onFinished, super.key});

  final BackendController backendController;
  final VoidCallback onFinished;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

enum _Phase { typingAi, erasingAi, typingBrand, done }

class _LaunchSplashState extends State<LaunchSplash> {
  static const _initialPause = Duration(milliseconds: 100);
  static const _typeStep = Duration(milliseconds: 65);
  static const _aiHoldPause = Duration(milliseconds: 220);
  static const _eraseStep = Duration(milliseconds: 45);
  static const _brandTypeStep = Duration(milliseconds: 40);
  static const _finalPause = Duration(milliseconds: 300);

  static const _ai = 'AI';
  static const _brand = 'iAgentsHUB';

  Timer? _cursorTimer;
  bool _showCursor = false;
  String _visibleText = '';
  _Phase _phase = _Phase.typingAi;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    unawaited(_checkBackend());
    unawaited(_runSequence());
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkBackend() async {
    final apiClient = ApiClient(widget.backendController);
    final authRepository = AuthRepository(apiClient);
    try {
      final platform = await authRepository.platformPublic();
      BootPlatformCache.set(platform: platform, reachable: true);
    } catch (_) {
      BootPlatformCache.set(platform: null, reachable: false);
    }
  }

  Future<void> _runSequence() async {
    await Future<void>.delayed(_initialPause);
    if (mounted) setState(() => _showCursor = true);

    await _typeText(_ai, _typeStep);
    await Future<void>.delayed(_aiHoldPause);

    if (mounted) setState(() => _phase = _Phase.erasingAi);
    await _eraseText(_eraseStep);

    if (mounted) setState(() => _phase = _Phase.typingBrand);
    await _typeText(_brand, _brandTypeStep);

    if (mounted) setState(() => _phase = _Phase.done);
    await Future<void>.delayed(_finalPause);
    if (!mounted) return;
    widget.onFinished();
  }

  Future<void> _typeText(String fullText, Duration step) async {
    for (var i = _visibleText.length + 1; i <= fullText.length; i++) {
      if (!mounted) return;
      setState(() => _visibleText = fullText.substring(0, i));
      await Future<void>.delayed(step);
    }
  }

  Future<void> _eraseText(Duration step) async {
    for (var i = _visibleText.length - 1; i >= 0; i--) {
      if (!mounted) return;
      setState(() => _visibleText = _visibleText.substring(0, i));
      await Future<void>.delayed(step);
    }
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _showCursor = !_showCursor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _showCursor && _phase != _Phase.done ? '|' : '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF050505), Color(0xFF101010), Color(0xFF161616)],
          ),
        ),
        child: Center(child: _buildBrandLine(cursor)),
      ),
    );
  }

  Widget _buildBrandLine(String cursor) {
    final isBrandPhase = _phase == _Phase.typingBrand || _phase == _Phase.done;

    if (!isBrandPhase) {
      return Text(
        '$_visibleText$cursor',
        style: GoogleFonts.inter(
          color: const Color(0xFFFF5A73),
          fontSize: 44,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
          shadows: const [Shadow(color: Color(0xAA7A0C1C), blurRadius: 20)],
        ),
      );
    }

    final prefixLen = _visibleText.length <= 7 ? _visibleText.length : 7;
    final prefix = _visibleText.substring(0, prefixLen);
    final suffix = _visibleText.length > 7 ? _visibleText.substring(7) : '';

    // Row + CrossAxisAlignment.baseline (no RichText/WidgetSpan): así el
    // texto dentro de la píldora "HUB" se asienta en la misma línea base
    // que "iAgents" en vez de centrarse respecto a la altura de línea.
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          prefix,
          style: GoogleFonts.inter(
            color: const Color(0xFFFFFFFF),
            fontSize: 44,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        if (suffix.isNotEmpty) const SizedBox(width: 8),
        if (suffix.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFD90429),
              borderRadius: BorderRadius.circular(7),
              boxShadow: const [BoxShadow(color: Color(0xAA7A0C1C), blurRadius: 16, spreadRadius: 0.3)],
            ),
            child: Text(
              suffix,
              style: GoogleFonts.inter(color: const Color(0xFFFFFFFF), fontSize: 34, fontWeight: FontWeight.w800),
            ),
          ),
        if (cursor.isNotEmpty)
          Text(
            cursor,
            style: GoogleFonts.inter(color: const Color(0xFFFFFFFF), fontSize: 44, fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}
