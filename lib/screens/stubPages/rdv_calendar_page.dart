import 'package:cleaning_schedule_demo/controllers/auth_controller.dart';
import 'package:cleaning_schedule_demo/controllers/rdv_controller.dart';
import 'package:cleaning_schedule_demo/controllers/workers_controller.dart';
import 'package:cleaning_schedule_demo/models/rdv_model.dart';
import 'package:cleaning_schedule_demo/screens/rdvs/rdv_form_page.dart';
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
  final AuthController _authController = AuthController();

  Map<DateTime, List<RdvModel>> rdvEvents = {};
  Map<String, String> monitorsMap = {};
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRdvs();
    _loadWorkers();
    _loadMonitors();
  }

  Future<void> _loadRdvs() async {
    setState(() => _loading = true);
    rdvEvents = await _rdvController.loadRdvs();
    if(!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _loadWorkers() async {
    await _workersController.loadWorkers();
    setState(() {});
  }

  Future<void> _loadMonitors() async {
    monitorsMap = await _authController.loadMonitorsMap();
    setState(() {});
  }

  List<RdvModel> _getEventsForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return rdvEvents[d] ?? [];
  }

  Future<bool> _openRdvForm({RdvModel? rdv, DateTime? initialDate}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RdvFormPage(
          rdvData: rdv,
          initialDate: initialDate,
          workersMap: _workersController.workersMap,
          monitorsMap: monitorsMap,
        ),
      ),
    );
    return result == true;
  }

  List<String> _getWorkerNamesForRdv(RdvModel rdv) {
    final names = <String>[];

    // 🔹 Utilise la liste workerIds si elle existe
    if (rdv.workerIds.isNotEmpty) {
      for (final wid in rdv.workerIds) {
        final name = _workersController.workersMap[wid];
        if (name != null && name.trim().isNotEmpty) {
          names.add(name);
        }
      }
    } else {
      // 🔹 Rétro-compat : un seul workerId (et pas TEAM)
      if (rdv.workerId.isNotEmpty && rdv.workerId != 'TEAM') {
        final single = _workersController.workersMap[rdv.workerId];
        if (single != null && single.trim().isNotEmpty) {
          names.add(single);
        }
      }
    }

    return names;
  }

  String getRdvLabel(RdvModel rdv) {
    final workerNames = _getWorkerNamesForRdv(rdv);
    final hasMonitors = rdv.monitorIds.isNotEmpty;
    final hasTeam = rdv.workerId == 'TEAM' || workerNames.length > 1;

    if (hasTeam && hasMonitors) return 'Équipe + Moniteur(s)';
    if (hasTeam) return 'Équipe';
    if (workerNames.length == 1 && hasMonitors) return 'Travailleur + Moniteur(s)';
    if (workerNames.length == 1) return 'Travailleur';
    if (hasMonitors) return 'Moniteur(s)';
    return 'Inconnu';
  }

  /// Ligne compacte affichée dans la carte fermée
  String getRdvSubtitle(RdvModel rdv) {
    String text = rdv.heure;
    if (rdv.lieu?.isNotEmpty == true) {
      text += " • ${rdv.lieu}";
    }
    text += ' • ${getRdvLabel(rdv)}';
    return text;
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label : ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDayRdvsPage(DateTime day) async {
    final dayKey = DateTime(day.year, day.month, day.day);
    List<RdvModel> events = List.from(_getEventsForDay(dayKey));
    // 🔹 pour gérer l'état "ouvert/fermé" de chaque carte RDV
    final Set<String> expandedIds = {};

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => SafeArea(
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
                    (rdv) {
                      final bool isExpanded = expandedIds.contains(rdv.id);
                      final workerNames = _getWorkerNamesForRdv(rdv);
                      final hasTeam = rdv.workerId == 'TEAM' || workerNames.length > 1;
                      final monitorsNames = rdv.monitorIds
                          .map((id) => monitorsMap[id] ?? 'Inconnu')
                          .toList();

                      return GestureDetector(
                        onTap: () {
                          setModalState(() {
                            if (isExpanded) {
                              expandedIds.remove(rdv.id);
                            } else {
                              expandedIds.add(rdv.id);
                            }
                          });
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: Column(
                            children: [
                              ListTile(
                                title: Text(
                                  rdv.motif.isNotEmpty ? rdv.motif : 'Sans motif',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  getRdvSubtitle(rdv),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
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
                                        if (result) {
                                          final updatedEvents = await _rdvController.loadRdvs();
                                          setState(() => rdvEvents = updatedEvents);
                                          setModalState(() {
                                            events = List.from(rdvEvents[dayKey] ?? []);
                                            expandedIds.remove(rdv.id);
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
                                        final deleted = await _rdvController.deleteRdv(
                                          context,
                                          rdv,
                                        );
                                        if (deleted) {
                                          rdvEvents[dayKey]?.removeWhere(
                                            (e) => e.id == rdv.id,
                                          );
                                          setState(() {});
                                          setModalState(() {
                                            events.removeWhere((e) => e.id == rdv.id);
                                            expandedIds.remove(rdv.id);
                                          });
                                        }
                                      },
                                    ),
                                    Icon(
                                      isExpanded
                                          ? Icons.expand_less
                                          : Icons.expand_more,
                                      color: Colors.grey,
                                    ),
                                  ],
                                ),
                              ),

                              // 🔻 Détails visibles seulement si la carte est "ouverte"
                              if (isExpanded)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildDetailRow('Heure', rdv.heure),
                                      _buildDetailRow(
                                        'Lieu',
                                        (rdv.lieu != null && rdv.lieu!.isNotEmpty)
                                            ? rdv.lieu!
                                            : 'Non précisé',
                                      ),
                                      if (workerNames.isNotEmpty)
                                        _buildDetailRow(
                                          hasTeam ? 'Équipe' : 'Travailleur',
                                          workerNames.join(', '),
                                        ),
                                      if (monitorsNames.isNotEmpty)
                                        _buildDetailRow(
                                          'Moniteur(s)',
                                          monitorsNames.join(', '),
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Ajouter un RDV'),
                    onTap: () async {
                      final result = await _openRdvForm(initialDate: day);
                      if (result) {
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
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Rendez-vous', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Column(
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 600),
                  child: TableCalendar<RdvModel>(
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
                    calendarBuilders: CalendarBuilders<RdvModel>(
                      markerBuilder: (context, day, events) {
                        final rdvs = events.cast<RdvModel>();
                        if (rdvs.isEmpty) return const SizedBox.shrink();

                        bool hasWorkersOnly = false;
                        bool hasMonitorsOnly = false;
                        bool hasBoth = false;

                        for (final r in rdvs) {
                          // 🔹 On utilise la même logique que dans le détail :
                          final workerNames = _getWorkerNamesForRdv(r);
                          final hasWorkers = workerNames.isNotEmpty || r.workerId == 'TEAM';
                          final hasMonitors = r.monitorIds.isNotEmpty;

                          if (hasWorkers && !hasMonitors) {
                            hasWorkersOnly = true;
                          } else if (!hasWorkers && hasMonitors) {
                            hasMonitorsOnly = true;
                          } else if (hasWorkers && hasMonitors) {
                            hasBoth = true;
                          }
                        }

                        // On construit les marqueurs
                        final List<Widget> markers = [];

                        if (hasWorkersOnly) {
                          markers.add(
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }

                        if (hasMonitorsOnly) {
                          markers.add(
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Colors.red, // 🔴 moniteurs
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }

                        if (hasBoth) {
                          markers.add(
                            const SizedBox(
                              width: 6,
                              height: 6,
                              child: CustomPaint(
                                painter: HalfCirclePainter(), // noir + rouge
                              ),
                            ),
                          );
                        }
                        if (markers.isEmpty) return const SizedBox.shrink();
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: markers
                              .map(
                                (m) => Padding(
                                  padding: const EdgeInsets.only(right: 2),
                                  child: m,
                                ),
                              )
                              .toList(),
                        );
                      },
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

// Demi-point noir/rose
class HalfCirclePainter extends CustomPainter {
  const HalfCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paintLeft = Paint()..color = Colors.black;
    final paintRight = Paint()..color = Colors.pink;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawArc(rect, 3.14 / 2, 3.14, true, paintLeft); // gauche noir
    canvas.drawArc(rect, -3.14 / 2, 3.14, true, paintRight); // droite rose
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
