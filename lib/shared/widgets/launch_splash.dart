import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LaunchSplash extends StatefulWidget {
  const LaunchSplash({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<LaunchSplash> createState() => _LaunchSplashState();
}

class _LaunchSplashState extends State<LaunchSplash> {
  static const _initialPause = Duration(milliseconds: 900);
  static const _shortPause = Duration(milliseconds: 660);
  static const _longPause = Duration(milliseconds: 1300);
  static const _typeStep = Duration(milliseconds: 210);
  static const _eraseStep = Duration(milliseconds: 180);

  static const _firstWord = 'AI';
  static const _secondWord = 'iAgentsHUB';

  Timer? _cursorTimer;
  bool _showCursor = false;
  String _visibleText = '';
  _SplashAction _action = _SplashAction.idle;

  @override
  void initState() {
    super.initState();
    _startCursorBlink();
    unawaited(_runSequence());
  }

  @override
  void dispose() {
    _cursorTimer?.cancel();
    super.dispose();
  }

  Future<void> _runSequence() async {
    if (mounted) {
      setState(() {
        _visibleText = '';
        _action = _SplashAction.idle;
        _showCursor = false;
      });
    }
    await Future<void>.delayed(_initialPause);
    if (mounted) {
      setState(() {
        _showCursor = true;
        _action = _SplashAction.typingAi;
      });
    }
    await _typeText(_firstWord, _typeStep);
    await Future<void>.delayed(_shortPause);
    if (mounted) setState(() => _action = _SplashAction.erasingAi);
    await _eraseText(_eraseStep);
    await Future<void>.delayed(const Duration(milliseconds: 260));
    if (mounted) setState(() => _action = _SplashAction.typingBrand);
    await _typeText(_secondWord, _typeStep);
    if (mounted) setState(() => _action = _SplashAction.done);
    await Future<void>.delayed(_longPause);
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
    final cursor = _showCursor && _visibleText.isNotEmpty ? '|' : '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF050505),
              Color(0xFF101010),
              Color(0xFF161616),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBrandLine(cursor),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  _captionForAction(),
                  key: ValueKey(_action),
                  style: GoogleFonts.inter(
                    color: const Color(0xFFE8E8E8),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    minHeight: 3,
                    value: _progressForAction(),
                    backgroundColor: const Color(0xFF2A2A2A),
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFD90429)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBrandLine(String cursor) {
    final rawText = _visibleText;

    if (rawText.startsWith('iAgents')) {
      final prefixLen = rawText.length <= 7 ? rawText.length : 7;
      final prefix = rawText.substring(0, prefixLen);
      final suffix = rawText.length > 7 ? rawText.substring(7) : '';

      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: GoogleFonts.inter(
                color: const Color(0xFFFFFFFF),
                fontSize: 50,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            if (suffix.isNotEmpty)
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: SizedBox(width: 8),
              ),
            if (suffix.isNotEmpty)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD90429),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0xAA7A0C1C),
                        blurRadius: 16,
                        spreadRadius: 0.3,
                      ),
                    ],
                  ),
                  child: Text(
                    suffix,
                    style: GoogleFonts.inter(
                      color: const Color(0xFFFFFFFF),
                      fontSize: 38,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            if (cursor.isNotEmpty)
              TextSpan(
                text: cursor,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFFFFF),
                  fontSize: 50,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
          ],
        ),
      );
    }

    final displayText = '$rawText$cursor';
    final isAiPhase = rawText.contains('A') || rawText.contains('I');
    return Text(
      displayText,
      style: GoogleFonts.inter(
        color: isAiPhase ? const Color(0xFFFF5A73) : const Color(0xFFFFFFFF),
        fontSize: 50,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        shadows: const [
          Shadow(color: Color(0xAA7A0C1C), blurRadius: 20),
        ],
      ),
    );
  }

  String _captionForAction() {
    switch (_action) {
      case _SplashAction.typingAi:
        return 'typing AI...';
      case _SplashAction.erasingAi:
        return 'deleting AI...';
      case _SplashAction.typingBrand:
        return 'loading iAgentsHUB...';
      case _SplashAction.done:
        return 'access granted';
      case _SplashAction.idle:
        return '';
    }
  }

  double _progressForAction() {
    switch (_action) {
      case _SplashAction.idle:
        return 0.05;
      case _SplashAction.typingAi:
        return 0.28;
      case _SplashAction.erasingAi:
        return 0.45;
      case _SplashAction.typingBrand:
        return 0.78;
      case _SplashAction.done:
        return 1;
    }
  }
}

enum _SplashAction { idle, typingAi, erasingAi, typingBrand, done }