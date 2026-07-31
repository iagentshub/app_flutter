part of '../pages/login_page.dart';

extension _LoginHero on _LoginPageState {
  Widget _buildHeroPanel(BuildContext context) {
    return Container(
      color: const Color(0xFF0B0B0B),
      padding: const EdgeInsets.all(48),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _authTextsFuture,
        builder: (context, snapshot) {
          final t = snapshot.data ?? const {};
          final headlinePre = _txt(t, 'headline_pre', _isEnglish ? 'in' : 'en');
          final headline1 = _txt(
            t,
            'headline_1',
            _isEnglish ? 'All your AI' : 'Toda tu IA',
          );
          final headlineAccent = _txt(
            t,
            'headline_accent',
            _isEnglish ? 'one place' : 'un solo lugar',
          );
          final heroSub = _txt(
            t,
            'hero_sub',
            _isEnglish
                ? 'Agents, knowledge, workflows and connections — from your phone, your desktop, or the web.'
                : 'Agentes, conocimiento, workflows y conexiones — desde tu móvil, tu escritorio o la web.',
          );

          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandMark(scale: 1.6),
              const SizedBox(height: 24),
              Text(
                '$headline1 $headlinePre\n$headlineAccent',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                heroSub,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
