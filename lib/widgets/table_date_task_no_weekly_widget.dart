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
  final CollectionReference eventsRef =
      FirebaseFirestore.instance.collection('events');

  bool _loading = true;
  List<Map<String, dynamic>> _taskEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    try {
      final snapshot = await eventsRef.get();

      // 🔹 Récupère uniquement les events de la tâche concernée
      final allEvents = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['day'] as Timestamp?;
        final date = ts?.toDate();

        return {
          'task': data['task'] ?? '',
          'place': data['place'] ?? '',
          'isWeeklyTask': data['isWeeklyTask'] ?? true,
          'day': date,
        };
      }).where((e) => e['task'] == widget.taskName).toList();

      // 🔹 Tri chronologique (plus ancien -> plus récent)
      allEvents.sort((a, b) =>
          (a['day'] as DateTime).compareTo(b['day'] as DateTime));

      setState(() {
        _taskEvents = allEvents;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement events: $e');
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.taskName),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _taskEvents.isEmpty
              ? const Center(
                  child: Text(
                    'Aucun événement pour cette tâche.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _taskEvents.length,
                  itemBuilder: (context, index) {
                    final event = _taskEvents[index];
                    final date = event['day'] as DateTime?;
                    final formattedDate = date != null
                        ? DateFormat('dd MMM yyyy', 'fr_FR').format(date)
                        : '—';

                    bool late = false;
                    bool reprogrammed = false;

                    if (date != null) {
                      final diffDays = now.difference(date).inDays;

                      // 🔹 Si + de 10 jours → rouge
                      if (diffDays > 10 && date.isBefore(now)) {
                        late = true;
                      }

                      // 🔹 Si une autre date future existe → gris
                      reprogrammed = _taskEvents.any((other) {
                        final d2 = other['day'] as DateTime?;
                        return d2 != null && d2.isAfter(now);
                      });
                    }

                    // 🔹 Choix de la couleur
                    Color color;
                    if (reprogrammed) {
                      color = Colors.grey;
                    } else if (late) {
                      color = Colors.red;
                    } else {
                      color = Colors.black;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: late
                            ? Colors.red.withValues(alpha: 0.08)
                            : reprogrammed
                                ? Colors.grey.withValues(alpha: 0.08)
                                : Colors.transparent,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              formattedDate,
                              style: TextStyle(
                                fontSize: 14,
                                color: color,
                                fontWeight:
                                    late ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              event['place'] ?? '',
                              style: TextStyle(
                                fontSize: 14,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
