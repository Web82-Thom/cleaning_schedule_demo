import 'dart:async';

import 'package:cleaning_schedule_demo/widgets/weeklyScheduleType/weekly_schedule_type.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ScheduleController extends ChangeNotifier {
  /// Charge tous les events depuis Firestore
  Future<List<Map<String, dynamic>>> loadAllEvents() async {
    final eventsSnapshot =
        await FirebaseFirestore.instance.collection('events').get();

    final events = eventsSnapshot.docs.map((doc) {
      final data = doc.data();
      dynamic subPlace = data['subPlace'];
      if (subPlace == null) {
        subPlace = <String>[];
      } else if (subPlace is String) {
        if (subPlace.trim().isEmpty || subPlace.trim() == '[]') {
          subPlace = <String>[];
        } else {
          subPlace = [subPlace];
        }
      } else if (subPlace is! List) {
        subPlace = <String>[];
      }

      return {
        'id': doc.id,
        'day': (data['day'] as Timestamp).toDate(),
        'timeSlot': data['timeSlot'] ?? 'morning',
        'place': data['place'] ?? '',
        'subPlace': subPlace,
        'task': data['task'] ?? '',
        'workerIds': List<String>.from(data['workerIds'] ?? []),
        'isWeeklyTask': data['isWeeklyTask'] ?? true,
      };
    }).toList();

    return [...events];
  }

  // ─────────────────────────────────────────────────────────────
  // 🔹 Helpers pour la gestion des semaines déjà générées
  // ─────────────────────────────────────────────────────────────

  /// Id unique pour une semaine donnée (on utilise le lundi + type poussière ou non)
  String _weekDocId({
    required DateTime mondayDate,
    required bool dustWeek,
  }) {
    final y = mondayDate.year;
    final m = mondayDate.month.toString().padLeft(2, '0');
    final d = mondayDate.day.toString().padLeft(2, '0');
    final type = dustWeek ? 'dust' : 'std';
    return '$y-$m-$d-$type';
  }

  /// Vérifie dans Firestore si un planning type a déjà été généré pour cette semaine
  Future<bool> _hasAlreadyGeneratedWeek({
    required DateTime mondayDate,
    required bool dustWeek,
  }) async {
    final id = _weekDocId(mondayDate: mondayDate, dustWeek: dustWeek);
    final doc = await FirebaseFirestore.instance
        .collection('generated_weeks')
        .doc(id)
        .get();
    return doc.exists;
  }

  /// Marque une semaine comme générée dans Firestore
  Future<void> _markWeekAsGenerated({
    required DateTime mondayDate,
    required int weekNumber,
    required bool dustWeek,
  }) async {
    final id = _weekDocId(mondayDate: mondayDate, dustWeek: dustWeek);
    await FirebaseFirestore.instance
        .collection('generated_weeks')
        .doc(id)
        .set({
      'mondayDate': Timestamp.fromDate(mondayDate),
      'weekNumber': weekNumber,
      'dustWeek': dustWeek,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────────────────────
  // 🔹 Dialog de génération de planning type
  // ─────────────────────────────────────────────────────────────

  Future<void> showDialogGeneratedWeeklyScheduleType({
    required BuildContext context,
    required DateTime selectedDate,
    required int weekNumber,
  }) async {
    bool isDustWeek = false; // coche pour poussière

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Générer un planning type'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Souhaitez-vous générer un planning type pour cette semaine ?',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Checkbox(
                        value: isDustWeek,
                        onChanged: (val) => setState(() => isDustWeek = val ?? false),
                      ),
                      const Text('Semaine poussière'),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                  ),
                  onPressed: () async {
                    // 🔹 Calcule le lundi de la semaine courante
                    final mondayDate = selectedDate.subtract(
                      Duration(
                        days: selectedDate.weekday - DateTime.monday,
                      ),
                    );

                    // 🔹 Vérifie si un planning pour cette semaine existe déjà
                    final alreadyGenerated = await _hasAlreadyGeneratedWeek(
                      mondayDate: mondayDate,
                      dustWeek: isDustWeek,
                    );

                    if (alreadyGenerated) {
                      // On ferme le dialog et on affiche un message
                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Un planning type pour cette semaine a déjà été généré. ❌',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Sinon, on peut générer
                    Navigator.pop(ctx); // ferme le dialog
                    await generateWeeklyScheduleType(
                      context: context,
                      selectedDate: selectedDate,
                      weekNumber: weekNumber,
                      dustWeek: isDustWeek,
                    );
                  },
                  child: const Text('Générer', style: TextStyle(color: Colors.white),),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 🔹 Génération effective de la semaine type
  // ─────────────────────────────────────────────────────────────

  Future<void> generateWeeklyScheduleType({
    required BuildContext context,
    required DateTime selectedDate,
    required int weekNumber,
    required bool dustWeek,
  }) async {
    OverlayEntry? overlay; // ✅ Déclaré ici, visible dans tout le scope

    try {
      // 🔹 Calcule le lundi de la semaine
      final mondayDate = selectedDate.subtract(
        Duration(days: selectedDate.weekday - DateTime.monday),
      );

      // 🔹 Sécurité supplémentaire : on revérifie côté génération
      final alreadyGenerated = await _hasAlreadyGeneratedWeek(
        mondayDate: mondayDate,
        dustWeek: dustWeek,
      );
      if (alreadyGenerated) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Le planning type pour cette semaine existe déjà, génération annulée. ❌',
              ),
            ),
          );
        }
        return;
      }

      // 🔹 Crée un OverlayEntry (loader global, pas de dialog)
      overlay = OverlayEntry(
        builder: (_) => Container(
          color: Colors.black.withOpacity(0.3),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(color: Colors.indigo),
        ),
      );

      // 🔹 Insère le loader
      Overlay.of(context, rootOverlay: true).insert(overlay);

      // 🔹 Génère les événements
      final events = generateWeekTypeEvents(
        mondayDate: mondayDate,
        weekNumber: weekNumber,
        dustWeek: dustWeek,
      );

      // 🔹 Envoi Firestore (batch)
      final batch = FirebaseFirestore.instance.batch();
      final eventsRef = FirebaseFirestore.instance.collection('events');
      for (final e in events) {
        batch.set(eventsRef.doc(), e);
      }
      await batch.commit();

      // 🔹 Marque cette semaine comme générée
      await _markWeekAsGenerated(
        mondayDate: mondayDate,
        weekNumber: weekNumber,
        dustWeek: dustWeek,
      );

      // 🔹 Retire le loader
      overlay.remove();
      overlay = null; // ✅ sécurité

      // 🔹 Affiche confirmation
      if (context.mounted) {
        final type = dustWeek ? "poussière" : "hebdomadaire";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Planning type $type généré avec succès ✅')),
        );
      }
    } catch (e) {
      // 🔹 Retire le loader en cas d’erreur aussi
      if (overlay != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          overlay?.remove();
        });
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération planning : $e')),
        );
      }
    }
  }
}
