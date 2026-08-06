import 'package:flutter/material.dart';

import '../../app/theme/fnc_colors.dart';

class PublicPage extends StatelessWidget {
  const PublicPage({
    required this.title,
    required this.description,
    required this.actions,
    super.key,
  });

  final String title;
  final String description;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [FncColors.gray070707, FncColors.gray111111],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  color: FncColors.gray151515,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: FncColors.gray2B2B2B),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: textTheme.headlineMedium?.copyWith(
                            color: FncColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          description,
                          style: textTheme.bodyLarge?.copyWith(
                            color: FncColors.grayE8E8E8,
                            height: 1.55,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: 78,
                          height: 4,
                          decoration: BoxDecoration(
                            color: FncColors.red,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Wrap(spacing: 12, runSpacing: 12, children: actions),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
