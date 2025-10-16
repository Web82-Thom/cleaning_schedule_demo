import 'package:cleaning_schedule/controllers/rdv_controller.dart';
import 'package:cleaning_schedule/controllers/workers_controller.dart';
import 'package:cleaning_schedule/models/rdv_model.dart';
import 'package:cleaning_schedule/screens/rdvs/rdv_form_page.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class RdvCalendarPage extends StatefulWidget {
  const RdvCalendarPage({super.key});

  @override
  State<RdvCalendarPage> createState() => _RdvCalendarPageState();
}

class _RdvCalendarPageState extends State<RdvCalendarPage> {
  final RdvController _rdvController = RdvController();
  final WorkersController _workersController = WorkersController();

  Map<DateTime, List<RdvModel>> rdvEvents = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRdvs();
    _workersController.loadWorkers();
  }

  // Chargement des RDVs depuis Firestore
  Future<void> _loadRdvs() async {
    setState(() => _loading = true);
    rdvEvents = await _rdvController.loadRdvs();
    setState(() => _loading = false);
  }

  // Récupérer les RDVs pour un jour donné
  List<RdvModel> _getEventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return rdvEvents[d] ?? [];
  }

  // Ouvre le formulaire de création/modification
  Future<bool> _openRdvForm({RdvModel? rdv, DateTime? initialDate}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RdvFormPage(
          rdvData: rdv,
          initialDate: initialDate,
          workersMap: _workersController.workersMap,
        ),
      ),
    );
    return result == true; // Retourne true si RDV créé/modifié
  }

  // BottomSheet affichant les RDVs d'une journée
  Future<void> _openDayRdvsPage(DateTime day) async {
    final dayKey = DateTime(day.year, day.month, day.day);
    List<RdvModel> events = List.from(_getEventsForDay(dayKey));

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Rendez-vous du ${DateFormat('dd/MM/yyyy').format(day)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),

                    ...events.map(
                      (rdv) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        child: ListTile(
                          title: Text(
                            '${rdv.workerId == "TEAM" ? "Équipe" : (_workersController.workersMap[rdv.workerId] ?? "Inconnu")} • ${rdv.motif}',
                          ),
                          subtitle: Text(
                            '${rdv.heure}${rdv.lieu?.isNotEmpty == true ? ' • ${rdv.lieu}' : ''}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blueAccent,
                                ),
                                onPressed: () async {
                                  final result = await _openRdvForm(rdv: rdv);
                                  if (result == true) {
                                    // Recharge depuis Firestore et update map
                                    final updatedEvents = await _rdvController
                                        .loadRdvs();
                                    setState(() => rdvEvents = updatedEvents);
                                    setModalState(() {
                                      events = List.from(
                                        rdvEvents[dayKey] ?? [],
                                      );
                                    });
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.redAccent,
                                ),
                                onPressed: () async {
                                  final deleted = await _rdvController
                                      .deleteRdv(context, rdv);
                                  if (deleted) {
                                    // Supprime dans map principale
                                    rdvEvents[dayKey]?.removeWhere(
                                      (e) => e.id == rdv.id,
                                    );
                                    setModalState(() {
                                      events.removeWhere((e) => e.id == rdv.id);
                                    });
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Ajouter un RDV'),
                      onTap: () async {
                        final result = await _openRdvForm(initialDate: day);
                        if (result == true) {
                          final updatedEvents = await _rdvController.loadRdvs();
                          setState(() => rdvEvents = updatedEvents);
                          setModalState(() {
                            events = List.from(rdvEvents[dayKey] ?? []);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Rendez-vous')),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return SingleChildScrollView(
            child: Column(
              children: [
                ConstrainedBox( 
                  constraints: const BoxConstraints( maxHeight: 600,), 
                  child: TableCalendar(
                    rowHeight: 60,
                    daysOfWeekHeight: 30,
                    locale: 'fr_FR',
                    firstDay: DateTime(DateTime.now().year - 1),
                    lastDay: DateTime(DateTime.now().year + 2),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    eventLoader: _getEventsForDay,
                    headerStyle: const HeaderStyle(formatButtonVisible: false),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                      _selectedDay = selectedDay;
                                  
                      final events = _getEventsForDay(selectedDay);
                      if (events.isNotEmpty) {
                        _openDayRdvsPage(selectedDay);
                      } else {
                        _openRdvForm(initialDate: selectedDay).then((result) {
                          if (result) _loadRdvs();
                        });
                      }
                    },
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                      ),
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
