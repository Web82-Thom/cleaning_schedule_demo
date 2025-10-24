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

  bool _isSearching = false; // 🔍 État de la recherche
  String _searchQuery = ''; // Texte tapé dans la recherche

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
      await eventsRef.add({
        'task': data['task'],
        'place': data['place'],
        'isWeeklyTask': data['isWeeklyTask'],
        'day': Timestamp.fromDate(newDate),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: eventsRef.where('isWeeklyTask', isEqualTo: false).snapshots(),
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
          final List<Map<String, dynamic>> overdueTasks = [];
          final List<Map<String, dynamic>> upcomingTasks = [];

          for (final doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final ts = data['day'] as Timestamp?;
            final date = ts?.toDate();
            if (date == null) continue;

            // 🔹 Filtrage par recherche
            final taskName = (data['task'] ?? '').toString().toLowerCase();
            final place = (data['place'] ?? '').toString().toLowerCase();
            if (_searchQuery.isNotEmpty &&
                !taskName.contains(_searchQuery) &&
                !place.contains(_searchQuery)) continue;

            final diffDays = now.difference(date).inDays;
            final isPast = date.isBefore(DateTime(now.year, now.month, now.day));

            if (isPast && diffDays > 10) {
              overdueTasks.add({...data, 'diffDays': diffDays});
            } else {
              upcomingTasks.add(data);
            }
          }

          int compareDate(a, b) =>
              (a['day'] as Timestamp).toDate().compareTo((b['day'] as Timestamp).toDate());
          overdueTasks.sort(compareDate);
          upcomingTasks.sort(compareDate);

          return ListView(
            padding: const EdgeInsets.all(8),
            children: [
              if (overdueTasks.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Text(
                    '⏰ Tâches à reprogrammer',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
              ...overdueTasks.map((data) {
                final date = (data['day'] as Timestamp).toDate();
                final formattedDate =
                    DateFormat('EEEE d MMM yyyy', 'fr_FR').format(date);
                final diffDays = data['diffDays'] ?? 0;
                final displayDays = diffDays + 2;

                return Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.warning, color: Colors.red),
                    title: Text(
                      data['task'] ?? '',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text('${data['place'] ?? ''}\n$formattedDate'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+$displayDays j',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Reprogrammer cette tâche ?'),
                          content: const Text(
                              'Voulez-vous créer une nouvelle occurrence ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Oui, reprogrammer'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await _reprogramTask(context, data);
                      }
                    },
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
    );
  }
}
