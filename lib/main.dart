import 'package:cleaning_schedule_demo/screens/consumables/list_pdf_cars_page.dart';
import 'package:cleaning_schedule_demo/screens/consumables/widgets/list_pdf_page.dart';
import 'package:cleaning_schedule_demo/screens/list_pdf_schedule_weekly_page.dart';
import 'package:cleaning_schedule_demo/screens/more_app.dart/about_page.dart';
import 'package:cleaning_schedule_demo/screens/more_app.dart/documentation_pdf.dart';
import 'package:cleaning_schedule_demo/screens/planning/event_from_page.dart';
import 'package:cleaning_schedule_demo/screens/planning/list_tasks_no_weekly_page.dart';
import 'package:cleaning_schedule_demo/screens/planning/to_do_list_page.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:cleaning_schedule_demo/screens/instructors/instructor_profile_page.dart';
import 'package:cleaning_schedule_demo/screens/places/list_place_page.dart';
import 'package:cleaning_schedule_demo/screens/workers/list_workers_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'screens/auth/login_page.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Affiche juste la barre du haut, cache la navigation, et garde le sticky
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual, overlays: [SystemUiOverlay.top]);

  await initializeDateFormatting('fr_FR', null);
  // Bloquer l'app en portrait uniquement
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    if (kIsWeb) {
      // ✅ WEB
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else if (Platform.isWindows) {
      // ✅ WINDOWS
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      // ✅ MOBILE (Android / iOS / macOS / Linux)
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e, stack) {
    debugPrint('🔥 Erreur lors de l’initialisation de Firebase : $e');
    debugPrintStack(stackTrace: stack);

    // En cas d’erreur critique, afficher une UI minimale
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Erreur d’initialisation Firebase.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
    return; // stoppe l’exécution ici
  }

  runApp(const CleaningScheduleApp());
}

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class CleaningScheduleApp extends StatelessWidget {
  const CleaningScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // 🔐 Fournit l'état FirebaseAuth à toute l'application
        StreamProvider<User?>.value(
          value: FirebaseAuth.instance.authStateChanges(),
          initialData: null,
        ),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Cleaning Schedule',
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [
          Locale('fr', 'FR'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.indigo,
          scaffoldBackgroundColor: const Color(0xFFF7F9FB),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
          ),
        ),
        home: const AuthWrapper(),
        routes: {
          '/home': (context) => HomePage(),
          '/listPlace': (context) => const ListPlace(),
          '/workers': (context) => const ListWorkersPage(),
          '/createdPlanning': (context) => const EventFormPage(),
          '/profileInstructor': (context) => const InstructorProfilePage(),
          '/listEventsNoWeekly': (context) => NoWeeklyTasksPage(),
          '/listPdfScheduleWeekly': (context) => ListPdfScheduleWeeklyPage(),
          '/listPdfCars': (context) => const ListPdfCarsPage(),
          '/toDoListPage' : (context) => const ToDoListPage(),
          '/listPdfHomeOfLife': (_) => const ListPdfPage(),
          '/listPdfTransfer': (_) => const ListPdfPage(),
          '/listPdfVillas' : (_) => const ListPdfPage(),
          '/listPdfOtherPlaces' : (_) => const ListPdfPage(),
          '/listPdfProducts' : (context) => ListPdfPage(),
          '/about' : (context) => AboutPage(),
          '/docAppPdf' : (context) => DocumentationsPdfPage(),
        },
      ),
    );
  }
}

/// Gère la navigation en fonction de l’état de connexion Firebase.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    // 👇 Si l’utilisateur est connecté → HomePage, sinon → LoginPage
    if (user == null) {
      return const LoginPage();
    } else {
      return HomePage();
    }
  }
}
