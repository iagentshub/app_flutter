part of '../pages/home_page.dart';

class _StatChip extends StatelessWidget {
  const _StatChip({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        border: Border(
          right: label == 'PRIVADO'
              ? BorderSide.none
              : const BorderSide(color: FncColors.gray5A5A5A),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            number,
            style: const TextStyle(
              fontSize: FncFonts.size28,
              fontWeight: FontWeight.w800,
              color: FncColors.white,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: FncFonts.size10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
              color: FncColors.grayD0D0D0,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FncColors.gray171717,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FncColors.gray2B2B2B),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: FncFonts.size16,
                fontWeight: FontWeight.w700,
                color: FncColors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(
                fontSize: FncFonts.size13,
                height: 1.5,
                color: FncColors.grayE2E2E2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
