import 'dart:async';

import 'package:cleaning_schedule/widgets/weeklyScheduleType/weekly_schedule_type.dart';
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

  /// 🔹 Génère un planning type (Lundi uniquement pour le test)
  /// 🔹 Affiche un dialogue pour générer une semaine type
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
                  onPressed: () async {
                    Navigator.pop(ctx); // ferme le dialog de confirmation
                    await generateWeeklyScheduleType(
                      context: context,
                      selectedDate: selectedDate,
                      weekNumber: weekNumber,
                      dustWeek: isDustWeek,
                    );
                  },
                  child: const Text('Générer'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  /// 🔹 Génère et insère le planning complet de la semaine (L→V)
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

      // 🔹 Envoi Firestore
      final batch = FirebaseFirestore.instance.batch();
      final eventsRef = FirebaseFirestore.instance.collection('events');
      for (final e in events) {
        batch.set(eventsRef.doc(), e);
      }
      await batch.commit();

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
