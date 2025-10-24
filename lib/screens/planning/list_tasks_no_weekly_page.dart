import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class NoWeeklyTasksPage extends StatefulWidget {
  const NoWeeklyTasksPage({super.key});

  @override
  State<NoWeeklyTasksPage> createState() => _NoWeeklyTasksPageState();
}

class _NoWeeklyTasksPageState extends State<NoWeeklyTasksPage> {
  final CollectionReference eventsRef =
      FirebaseFirestore.instance.collection('events');

  final CollectionReference monitoringRef =
      FirebaseFirestore.instance.collection('noWeeklyTasksMonitoring');

  bool _isSearching = false;
  String _searchQuery = '';

  /// 🔹 Reprogrammer une tâche et l’enregistrer dans le suivi
  Future<void> _reprogramTask(
    BuildContext context,
    Map<String, dynamic> data,
  ) async {
    DateTime? newDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null) return;

    try {
      // ✅ 1. Marquer l’ancienne tâche comme reprogrammée
      final query = await eventsRef
          .where('task', isEqualTo: data['task'])
          .where('place', isEqualTo: data['place'])
          .where('day', isEqualTo: data['day'])
          .get();

      for (final doc in query.docs) {
        await doc.reference.update({'isReprogrammed': true});
      }

      // ✅ 2. Créer le nouvel event reprogrammé
      final newEvent = {
        'task': data['task'],
        'place': data['place'],
        'day': Timestamp.fromDate(newDate),
        'isWeeklyTask': false,
        'isReprogrammed': false,
        'createdAt': FieldValue.serverTimestamp(),
      };
      final newDoc = await eventsRef.add(newEvent);

      // ✅ 3. Enregistrer dans noWeeklyTaskMonitoring
      await monitoringRef.add({
        'task': data['task'],
        'place': data['place'],
        'oldDay': data['day'],
        'newDay': Timestamp.fromDate(newDate),
        'oldEventId': query.docs.isNotEmpty ? query.docs.first.id : null,
        'newEventId': newDoc.id,
        'action': 'reprogrammed',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tâche reprogrammée pour le ${DateFormat('dd MMM yyyy', 'fr_FR').format(newDate)} ✅',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur reprogrammation : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Rechercher une tâche...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase()),
              )
            : const Text('Tâches non hebdomadaires'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: eventsRef.where('isWeeklyTask', isEqualTo: false).where('isReprogrammed', isEqualTo: false).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;

            if (docs.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune tâche non hebdomadaire pour le moment.',
                  style: TextStyle(fontSize: 16),
                ),
              );
            }

            final now = DateTime.now();
            final List<Map<String, dynamic>> pastTasks = [];
            final List<Map<String, dynamic>> upcomingTasks = [];

            for (final doc in docs) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['day'] as Timestamp?;
              final date = ts?.toDate();
              if (date == null) continue;

              // 🔍 Filtre recherche
              final taskName = (data['task'] ?? '').toString().toLowerCase();
              final place = (data['place'] ?? '').toString().toLowerCase();
              if (_searchQuery.isNotEmpty &&
                  !taskName.contains(_searchQuery) &&
                  !place.contains(_searchQuery)) continue;

              final diffDays = now.difference(date).inDays;
              final isPast =
                  date.isBefore(DateTime(now.year, now.month, now.day));

              if (isPast) {
                pastTasks.add({...data, 'diffDays': diffDays});
              } else {
                upcomingTasks.add(data);
              }
            }

            int compareDate(a, b) =>
                (a['day'] as Timestamp)
                    .toDate()
                    .compareTo((b['day'] as Timestamp).toDate());
            pastTasks.sort(compareDate);
            upcomingTasks.sort(compareDate);

            return ListView(
              padding: const EdgeInsets.all(8),
              children: [
                if (pastTasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Text(
                      '⏰ Tâches effectuées',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ...pastTasks.map((data) {
                  final date = (data['day'] as Timestamp).toDate();
                  final formattedDate =
                      DateFormat('EEEE d MMM yyyy', 'fr_FR').format(date);
                  final diffDays = data['diffDays'] ?? 0;

                  Color bgColor = Colors.indigo.shade50;
                  Color textColor = Colors.black87;
                  IconData icon = Icons.check_circle_outline;
                  Color iconColor = Colors.indigo;

                  if (diffDays > 10) {
                    bgColor = Colors.red.shade50;
                    textColor = Colors.red;
                    icon = Icons.warning_amber_rounded;
                    iconColor = Colors.red;
                  } else if (diffDays > 0 && diffDays <= 10) {
                    bgColor = Colors.orange.shade50;
                    textColor = Colors.orange.shade800;
                    icon = Icons.access_time;
                    iconColor = Colors.orange.shade700;
                  }

                  return Card(
                    color: bgColor,
                    child: ListTile(
                      leading: Icon(icon, color: iconColor),
                      title: Text(
                        data['task'] ?? '',
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text('${data['place'] ?? ''}\n$formattedDate'),
                      trailing: diffDays > 0
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: iconColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '+$diffDays j',
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                      onTap: diffDays > 0
                          ? () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title:
                                      const Text('Reprogrammer cette tâche ?'),
                                  content: const Text(
                                      'Voulez-vous créer une nouvelle occurrence ?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Annuler'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child:
                                          const Text('Oui, reprogrammer'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _reprogramTask(context, data);
                              }
                            }
                          : null,
                    ),
                  );
                }),
                if (upcomingTasks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 6),
                    child: Text(
                      '📅 Tâches à venir',
                      style: TextStyle(
                        color: Colors.indigo.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ...upcomingTasks.map((data) {
                  final date = (data['day'] as Timestamp).toDate();
                  final formattedDate =
                      DateFormat('EEEE d MMM yyyy', 'fr_FR').format(date);
                  return Card(
                    color: Colors.indigo.shade50,
                    child: ListTile(
                      leading:
                          const Icon(Icons.schedule, color: Colors.indigo),
                      title: Text(
                        data['task'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                      subtitle: Text('${data['place'] ?? ''}\n$formattedDate'),
                    ),
                  );
                }),
              ],
            );
          },
        ),
      ),
    );
  }
}
