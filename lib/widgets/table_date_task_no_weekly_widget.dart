import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TableDateTaskNoWeeklyWidget extends StatefulWidget {
  final String taskName;

  const TableDateTaskNoWeeklyWidget({
    super.key,
    required this.taskName,
  });

  @override
  State<TableDateTaskNoWeeklyWidget> createState() =>
      _TableDateTaskNoWeeklyWidgetState();
}

class _TableDateTaskNoWeeklyWidgetState
    extends State<TableDateTaskNoWeeklyWidget> {
  final CollectionReference monitoringRef =
      FirebaseFirestore.instance.collection('noWeeklyTasksMonitoring');

  bool _loading = true;
  List<Map<String, dynamic>> _pastEvents = [];

  @override
  void initState() {
    super.initState();
    _loadPastNoWeeklyForTask();
  }

  Future<void> _loadPastNoWeeklyForTask() async {
    try {
      final snap = await monitoringRef
          .where('task', isEqualTo: widget.taskName)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['day'] as Timestamp?;
        final date = ts?.toDate();

        return {
          'task': (data['task'] ?? '').toString(),
          'place': (data['place'] ?? '').toString(),
          'isWeeklyTask': (data['isWeeklyTask'] ?? false) as bool,
          'day': date,
        };
      })
      // 👉 Uniquement les NON hebdo et déjà passées
      .where((e) {
        final date = e['day'] as DateTime?;
        if (date == null) return false;
        final d0 = DateTime(date.year, date.month, date.day);
        return (e['isWeeklyTask'] == false) && d0.isBefore(today);
      }).toList();

      // Tri du plus ancien au plus récent
      list.sort((a, b) =>
          (a['day'] as DateTime).compareTo(b['day'] as DateTime));

      setState(() {
        _pastEvents = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement noWeeklyTasksMonitoring: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi — ${widget.taskName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _pastEvents.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun historique pour cette tâche.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _pastEvents.length,
                  itemBuilder: (context, index) {
                    final e = _pastEvents[index];
                    final date = e['day'] as DateTime?;
                    final formattedDate = date != null
                        ? DateFormat('dd MMM yyyy', 'fr_FR').format(date)
                        : '—';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          vertical: 6, horizontal: 8),
                      elevation: 1,
                      child: ListTile(
                        title: Text(
                          e['place'] ?? '',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          formattedDate,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
