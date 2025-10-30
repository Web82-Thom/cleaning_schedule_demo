import 'package:cleaning_schedule/screens/home_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// --- 🧩 INSCRIPTION MONITEUR / MONITRICE ---
  Future<void> registerInstructor({
  required String nom,
  required String prenom,
  required String email,
  required String password,
  required BuildContext context,
  }) async {
    BuildContext? loaderContext;

    // 🔹 Affiche un loader modal sécurisé
    if (context.mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) {
          loaderContext = ctx;
          return const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          );
        },
      );
    }

    try {
      // 🔹 Création du compte Firebase
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('Erreur de création du compte.');

      // 🔹 Enregistrement dans Firestore
      await _db.collection('users').doc(user.uid).set({
        'nom': nom.trim(),
        'prenom': prenom.trim(),
        'email': email.trim(),
        'role': 'instructor',
        'actif': true,
        'dateCreation': FieldValue.serverTimestamp(),
      });

      // ✅ Ferme le loader si encore monté
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // ✅ Navigation vers HomePage
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Compte créé avec succès ✅')),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Message d’erreur Firebase
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erreur d’inscription Firebase')),
        );
      }
    } catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Message d’erreur générique
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur inattendue : $e')),
        );
      }
    }
  }

  /// --- 🧩 CONNEXION UTILISATEUR ---
  Future<void> loginUser({
  required String email,
  required String password,
  required BuildContext context,
  }) async {
    BuildContext? loaderContext;

    // 🔹 Affiche un loader modal sécurisé
    if (context.mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) {
          loaderContext = ctx;
          return const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          );
        },
      );
    }

    try {
      // 🔹 Connexion Firebase
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception("Utilisateur introuvable.");

      // 🔹 Vérifie le rôle Firestore
      final userDoc = await _db.collection('users').doc(user.uid).get();

      if (!userDoc.exists ||
          userDoc['role'] != 'instructor' ||
          userDoc['actif'] == false) {
        await _auth.signOut();
        throw Exception("Accès refusé : moniteur/trice inactif(ve) ou non autorisé(e).");
      }

      // ✅ Ferme le loader si encore monté
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // ✅ Navigation vers HomePage (safe)
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage()),
          (route) => false,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connexion réussie ✅")),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Affiche message Firebase
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Erreur de connexion Firebase')),
        );
      }
    } catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Message d’erreur générique
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  /// --- 🧩 CHARGEMENT DES MONITEURS ACTIFS ---
  Map<String, String> monitorIds = {};

  Future<Map<String, String>> loadMonitors() async {
    final snapshot = await _db
        .collection('users')
        .where('role', isEqualTo: 'instructor')
        .where('actif', isEqualTo: true)
        .get();

    return monitorIds = {
      for (var doc in snapshot.docs)
        doc.id: '${doc['prenom']} ${doc['nom']}',
    };
  }

  Future<Map<String, String>> loadMonitorsMap() async {
    final Map<String, String> monitorsMap = {};
    try {
      final snapshot = await _db
          .collection('users')
          .where('role', isEqualTo: 'instructor')
          .where('actif', isEqualTo: true)
          .get();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final nom = data['nom'] ?? '';
        final prenom = data['prenom'] ?? '';
        monitorsMap[doc.id] = '$prenom $nom';
      }
    } catch (e) {
      debugPrint('Erreur chargement des moniteurs: $e');
    }
    return monitorsMap;
  }

  /// --- 🧩 DÉCONNEXION ---
  Future<void> signOut(BuildContext context) async {
    try {
      await _auth.signOut();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déconnexion réussie 👋')),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de déconnexion : $e')),
        );
      }
    }
  }

  /// --- 🧩 REZET PASSWORD ---
  Future<void> resetPassword({
    required String email,
    required BuildContext context,
  }) async {
    BuildContext? loaderContext;

    if (email.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez entrer une adresse e-mail.')),
      );
      return;
    }

    // 🔹 Affiche un loader modal sécurisé
    if (context.mounted) {
      showDialog(
        context: context,
        useRootNavigator: true,
        barrierDismissible: false,
        builder: (ctx) {
          loaderContext = ctx;
          return const Center(
            child: CircularProgressIndicator(color: Colors.indigo),
          );
        },
      );
    }

    try {
      await _auth.sendPasswordResetEmail(email: email.trim());

      // ✅ Ferme le loader si encore monté
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // ✅ Message de succès
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '📨 Email de réinitialisation envoyé !\nVérifiez votre boîte mail.',
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Message d’erreur Firebase
      if (context.mounted) {
        String errorMessage = 'Erreur : ${e.message}';
        if (e.code == 'user-not-found') {
          errorMessage = 'Aucun utilisateur trouvé avec cet email.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Adresse e-mail invalide.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      // 🔹 Ferme le loader proprement
      if (loaderContext != null && loaderContext!.mounted && Navigator.canPop(loaderContext!)) {
        Navigator.of(loaderContext!).pop();
      }

      // 🔹 Message d’erreur générique
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur inattendue : $e')),
        );
      }
    }
  }

}
