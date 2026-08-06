part of '../pages/pricing_page.dart';

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.name,
    required this.price,
    required this.description,
    required this.buttonLabel,
    required this.isPrimary,
  });

  final String name;
  final String price;
  final String description;
  final String buttonLabel;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: isPrimary ? FncColors.red : FncColors.gray333333,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(14),
        color: FncColors.gray101010,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: FncColors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: isPrimary ? FncColors.red : FncColors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: FncColors.grayD9D9D9),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              onPressed: () => AppRouter.toRegister(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: FncColors.red,
                foregroundColor: FncColors.white,
              ),
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
