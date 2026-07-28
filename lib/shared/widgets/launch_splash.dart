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

class _LaunchSplashState extends State<LaunchSplash> {
  static const _initialPause = Duration(milliseconds: 120);
  static const _typeStep = Duration(milliseconds: 42);
  static const _finalPause = Duration(milliseconds: 320);
  static const _brand = 'iAgentsHUB';

  Timer? _cursorTimer;
  bool _showCursor = false;
  String _visibleText = '';
  bool _done = false;

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
    for (var i = 1; i <= _brand.length; i++) {
      if (!mounted) return;
      setState(() => _visibleText = _brand.substring(0, i));
      await Future<void>.delayed(_typeStep);
    }
    if (mounted) setState(() => _done = true);
    await Future<void>.delayed(_finalPause);
    if (!mounted) return;
    widget.onFinished();
  }

  void _startCursorBlink() {
    _cursorTimer = Timer.periodic(const Duration(milliseconds: 420), (_) {
      if (!mounted) return;
      setState(() => _showCursor = !_showCursor);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cursor = _showCursor && !_done ? '|' : '';

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
    final prefixLen = _visibleText.length <= 7 ? _visibleText.length : 7;
    final prefix = _visibleText.substring(0, prefixLen);
    final suffix = _visibleText.length > 7 ? _visibleText.substring(7) : '';

    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: prefix,
            style: GoogleFonts.inter(
              color: const Color(0xFFFFFFFF),
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
          if (suffix.isNotEmpty) const WidgetSpan(alignment: PlaceholderAlignment.middle, child: SizedBox(width: 8)),
          if (suffix.isNotEmpty)
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: Container(
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
            ),
          if (cursor.isNotEmpty)
            TextSpan(
              text: cursor,
              style: GoogleFonts.inter(color: const Color(0xFFFFFFFF), fontSize: 44, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}
