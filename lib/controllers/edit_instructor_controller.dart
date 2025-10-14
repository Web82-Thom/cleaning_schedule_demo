import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EditInstructorController extends ChangeNotifier {
  final _firestore = FirebaseFirestore.instance;
  final userId = FirebaseAuth.instance.currentUser!.uid;

  /// 🔹 Dialogue pour créer un RDV
  Future<void> openAddRdvDialog(BuildContext context) async {
    final motifController = TextEditingController();
    final lieuController = TextEditingController();
    DateTime? dateRdv;
    TimeOfDay? heureDebut;
    TimeOfDay? heureFin;

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Nouveau rendez-vous',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motifController,
                    decoration: const InputDecoration(labelText: 'Motif'),
                  ),
                  TextField(
                    controller: lieuController,
                    decoration: const InputDecoration(
                      labelText: 'Lieu (optionnel)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: Text(
                      dateRdv == null
                          ? 'Choisir une date'
                          : 'Date : ${dateRdv!.day}/${dateRdv!.month}/${dateRdv!.year}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() => dateRdv = d);
                    },
                  ),
                  ListTile(
                    title: Text(
                      heureDebut == null
                          ? 'Heure de début'
                          : 'Début : ${heureDebut!.hour.toString().padLeft(2, '0')}h${heureDebut!.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (t != null) setState(() => heureDebut = t);
                    },
                  ),
                  ListTile(
                    title: Text(
                      heureFin == null
                          ? 'Heure de fin'
                          : 'Fin : ${heureFin!.hour.toString().padLeft(2, '0')}h${heureFin!.minute.toString().padLeft(2, '0')}',
                    ),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: heureDebut ?? TimeOfDay.now(),
                      );
                      if (t != null) setState(() => heureFin = t);
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (motifController.text.isEmpty ||
                              dateRdv == null ||
                              heureDebut == null ||
                              heureFin == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Veuillez remplir tous les champs obligatoires',
                                ),
                              ),
                            );
                            return;
                          }

                          final debut = DateTime(
                            dateRdv!.year,
                            dateRdv!.month,
                            dateRdv!.day,
                            heureDebut!.hour,
                            heureDebut!.minute,
                          );

                          final fin = DateTime(
                            dateRdv!.year,
                            dateRdv!.month,
                            dateRdv!.day,
                            heureFin!.hour,
                            heureFin!.minute,
                          );

                          await _firestore
                              .collection('users')
                              .doc(userId)
                              .collection('rdvs')
                              .add({
                                'motif': motifController.text,
                                'lieu': lieuController.text,
                                'debut': Timestamp.fromDate(debut),
                                'fin': Timestamp.fromDate(fin),
                                'createdAt': Timestamp.now(),
                              });

                          if (context.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Enregistrer'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🔹 Confirmation et suppression d'un RDV
  Future<void> deleteRdv(BuildContext context, String rdvId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: const Text('Voulez-vous vraiment supprimer ce rendez-vous ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('rdvs')
          .doc(rdvId)
          .delete();
    }
  }

  /// 🔹 Modifier un RDV existant
Future<void> editRdvDialog(
  BuildContext context,
  String rdvId,
  Map<String, dynamic> rdvData,
) async {
  final motifController = TextEditingController(text: rdvData['motif'] ?? '');
  final lieuController = TextEditingController(text: rdvData['lieu'] ?? '');
  DateTime? dateRdv = (rdvData['debut'] as Timestamp?)?.toDate();
  TimeOfDay? heureDebut = dateRdv != null ? TimeOfDay(hour: dateRdv.hour, minute: dateRdv.minute) : null;
  DateTime? finRdv = (rdvData['fin'] as Timestamp?)?.toDate();
  TimeOfDay? heureFin = finRdv != null ? TimeOfDay(hour: finRdv.hour, minute: finRdv.minute) : null;

  await showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(10),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: StatefulBuilder(
            builder: (context, setState) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Modifier le rendez-vous',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: motifController,
                  decoration: const InputDecoration(labelText: 'Motif'),
                ),
                TextField(
                  controller: lieuController,
                  decoration: const InputDecoration(labelText: 'Lieu (optionnel)'),
                ),
                const SizedBox(height: 10),
                ListTile(
                  title: Text(
                    dateRdv == null
                        ? 'Choisir une date'
                        : 'Date : ${dateRdv!.day}/${dateRdv!.month}/${dateRdv!.year}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: dateRdv ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (d != null) setState(() => dateRdv = DateTime(
                          d.year,
                          d.month,
                          d.day,
                          dateRdv?.hour ?? 0,
                          dateRdv?.minute ?? 0,
                        ));
                  },
                ),
                ListTile(
                  title: Text(
                    heureDebut == null
                        ? 'Heure de début'
                        : 'Début : ${heureDebut!.hour.toString().padLeft(2, '0')}h${heureDebut!.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: heureDebut ?? TimeOfDay.now(),
                    );
                    if (t != null && dateRdv != null) {
                      setState(() => heureDebut = t);
                      dateRdv = DateTime(
                        dateRdv!.year,
                        dateRdv!.month,
                        dateRdv!.day,
                        t.hour,
                        t.minute,
                      );
                    }
                  },
                ),
                ListTile(
                  title: Text(
                    heureFin == null
                        ? 'Heure de fin'
                        : 'Fin : ${heureFin!.hour.toString().padLeft(2, '0')}h${heureFin!.minute.toString().padLeft(2, '0')}',
                  ),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final t = await showTimePicker(
                      context: context,
                      initialTime: heureFin ?? TimeOfDay.now(),
                    );
                    if (t != null && dateRdv != null) {
                      setState(() => heureFin = t);
                      finRdv = DateTime(
                        dateRdv!.year,
                        dateRdv!.month,
                        dateRdv!.day,
                        t.hour,
                        t.minute,
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (motifController.text.isEmpty || dateRdv == null || heureDebut == null || heureFin == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Veuillez remplir tous les champs obligatoires'),
                            ),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(userId)
                            .collection('rdvs')
                            .doc(rdvId)
                            .update({
                          'motif': motifController.text,
                          'lieu': lieuController.text,
                          'debut': Timestamp.fromDate(dateRdv!),
                          'fin': Timestamp.fromDate(finRdv!),
                        });

                        if (context.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}



}
