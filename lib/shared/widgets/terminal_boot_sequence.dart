import 'dart:async';

import 'package:flutter/material.dart';

class TerminalBootSequence extends StatefulWidget {
  const TerminalBootSequence({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<TerminalBootSequence> createState() => _TerminalBootSequenceState();
}

class _TerminalBootSequenceState extends State<TerminalBootSequence> {
  static const _lineStep = Duration(milliseconds: 260);
  static const _finalPause = Duration(milliseconds: 620);
  static const _cursorStep = Duration(milliseconds: 420);

  static const _lines = [
    r'root@iagentshub:~$ auth --channel secure',
    r'[OK] identity verified',
    r'[OK] profile loaded',
    r'[OK] routes mapped',
    r'root@iagentshub:~$ open --workspace default',
  ];

  Timer? _lineTimer;
  Timer? _cursorTimer;
  int _visibleLines = 0;
  bool _showCursor = true;

  @override
  void initState() {
    super.initState();
    _cursorTimer = Timer.periodic(_cursorStep, (_) {
      if (!mounted) return;
      setState(() => _showCursor = !_showCursor);
    });
    _startSequence();
  }

  @override
  void dispose() {
    _lineTimer?.cancel();
    _cursorTimer?.cancel();
    super.dispose();
  }

  void _startSequence() {
    _lineTimer = Timer.periodic(_lineStep, (timer) {
      if (!mounted) return;
      if (_visibleLines < _lines.length) {
        setState(() => _visibleLines += 1);
        return;
      }

      timer.cancel();
      Future<void>.delayed(_finalPause, () {
        if (!mounted) return;
        widget.onFinished();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070707),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Container(
              margin: const EdgeInsets.all(18),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD90429).withValues(alpha: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'iAgents HUB :: secure terminal',
                    style: TextStyle(
                      color: Color(0xFFD90429),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (var i = 0; i < _visibleLines; i++) ...[
                    Text(
                      _lines[i],
                      style: const TextStyle(
                        color: Color(0xFFFFFFFF),
                        fontFamily: 'Courier',
                        fontSize: 14,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  if (_visibleLines >= _lines.length)
                    Text(
                      _showCursor ? '_' : ' ',
                      style: const TextStyle(
                        color: Color(0xFFD90429),
                        fontFamily: 'Courier',
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
