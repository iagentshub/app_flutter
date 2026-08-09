import 'package:app_flutter/features/public/widgets/public_profile_presentation.dart';
import 'package:app_flutter/models/profile/profile_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

String _tx(String path, String fallback) => fallback;

const _profile = SocialProfile(
  username: 'alice',
  bio: 'Diseñadora de agentes y automatizaciones para equipos de producto.',
  emailPublic: 'alice@example.com',
  github: 'https://github.com/alice',
  cv: '# Experiencia',
  languages: ['es', 'en'],
);

void main() {
  for (final width in [360.0, 1200.0]) {
    testWidgets('presentación profesional sin overflow a ${width.toInt()} px', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: PublicProfilePresentation(
                profile: _profile,
                avatar: const CircleAvatar(radius: 44, child: Text('A')),
                followersCount: 128,
                followingCount: 32,
                resourcesCount: 7,
                starsCount: 245,
                isOwnProfile: false,
                following: false,
                followBusy: false,
                onToggleFollow: () {},
                tx: _tx,
              ),
            ),
          ),
        ),
      );

      expect(find.text('@alice'), findsOneWidget);
      expect(find.text('245'), findsOneWidget);
      expect(find.text('Estrellas'), findsOneWidget);
      expect(find.text('Español'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('oculta seguir cuando se previsualiza el perfil propio', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PublicProfilePresentation(
            profile: _profile,
            avatar: const CircleAvatar(child: Text('A')),
            followersCount: 1,
            followingCount: 2,
            resourcesCount: 3,
            starsCount: 4,
            isOwnProfile: true,
            following: false,
            followBusy: false,
            onToggleFollow: () {},
            tx: _tx,
          ),
        ),
      ),
    );

    expect(find.text('Seguir'), findsNothing);
  });
}
