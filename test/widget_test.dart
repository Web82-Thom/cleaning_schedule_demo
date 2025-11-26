import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:cleaning_schedule_demo/main.dart';
import 'package:cleaning_schedule_demo/screens/home_page.dart';
import 'package:cleaning_schedule_demo/screens/auth/login_page.dart';

void main() {
  group('AuthWrapper Widget Tests', () {
    testWidgets('Affiche HomePage si utilisateur connecté', (WidgetTester tester) async {
      // 🔹 Créer un utilisateur mock connecté
      final mockUser = MockUser(
        isAnonymous: false,
        uid: '123',
        email: 'test@example.com',
      );

      // 🔹 Créer FirebaseAuth mock avec l’utilisateur connecté
      final mockAuth = MockFirebaseAuth(signedIn: true, mockUser: mockUser);

      // 🔹 Fournir le mock via StreamProvider
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            StreamProvider<User?>.value(
              value: mockAuth.authStateChanges(),
              initialData: mockUser,
            ),
          ],
          child: const MaterialApp(
            home: AuthWrapper(),
          ),
        ),
      );

      // 🔹 Attendre que le widget se stabilise
      await tester.pumpAndSettle();

      // 🔹 Vérifier que HomePage est affiché
      expect(find.byType(HomePage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('Affiche LoginPage si utilisateur non connecté', (WidgetTester tester) async {
      // 🔹 FirebaseAuth mock sans utilisateur connecté
      final mockAuth = MockFirebaseAuth(signedIn: false);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            StreamProvider<User?>.value(
              value: mockAuth.authStateChanges(),
              initialData: null,
            ),
          ],
          child: const MaterialApp(
            home: AuthWrapper(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 🔹 Vérifier que LoginPage est affiché
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(HomePage), findsNothing);
    });
  });
}
