import 'package:cleaning_schedule/controllers/pdf_controller.dart';
import 'package:cleaning_schedule/controllers/schedule_controller.dart';
import 'package:cleaning_schedule/controllers/workers_controller.dart';
import 'package:cleaning_schedule/screens/list_pdf_schedule_weekly_page.dart';
import 'package:cleaning_schedule/screens/planning/event_from_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WeeklyScheduleTableWidget extends StatefulWidget {
  final DateTime initialWeek;

  const WeeklyScheduleTableWidget({super.key, required this.initialWeek});

  @override
  State<WeeklyScheduleTableWidget> createState() =>
      _WeeklyScheduleTableWidgetState();
}

class _WeeklyScheduleTableWidgetState extends State<WeeklyScheduleTableWidget> {
  late DateTime _startOfWeek;
  late DateTime _endOfWeek;
  final ScheduleController _scheduleController = ScheduleController();
  final WorkersController workersController = WorkersController();
  Map<String, String> _workersMap = {}; // workerId → workerName
  
  int get _weekNumber => _getWeekNumber(_startOfWeek);

  @override
  void initState() {
    super.initState();
    _startOfWeek = _getStartOfWeek(widget.initialWeek);
    _endOfWeek = _startOfWeek.add(const Duration(days: 4));
    workersController.loadWorkers().then((map) {
      if(!mounted) return;
      setState(() {
        _workersMap = map;
      });
    });
  }

  //---HELPERS---//
    // Palette fixe pour des couleurs douces et lisibles
  final List<MaterialColor> _palette = const [
    Colors.blue, Colors.green, Colors.orange, Colors.teal, Colors.indigo,
    Colors.cyan, Colors.amber, Colors.lightGreen, Colors.deepOrange, Colors.pink,
    Colors.lime, Colors.deepPurple, Colors.brown, Colors.blueGrey, Colors.red,
  ];

  final Map<String, Color> _placeColorCache = {};

  // Hash FNV-1a 32-bit (déterministe)
  int _stableHash(String s) {
    int h = 0x811C9DC5; // 2166136261
    const int prime = 0x01000193; // 16777619
    for (final codeUnit in s.codeUnits) {
      h ^= codeUnit;
      h = (h * prime) & 0xFFFFFFFF;
    }
    return h;
  }

  Color _colorForPlace(String place) {
    if (_placeColorCache.containsKey(place)) return _placeColorCache[place]!;
    final idx = _stableHash(place).abs() % _palette.length;
    final color = _palette[idx].shade200;
    _placeColorCache[place] = color;
    return color;
  }

  // ---------- Semaine ----------
  DateTime _getStartOfWeek(DateTime date) => date.subtract(Duration(days: date.weekday - 1));

  List<DateTime> get _weekDays => List.generate(5, (i) => _startOfWeek.add(Duration(days: i)));

  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysOffset = firstDayOfYear.weekday - DateTime.monday;
    final firstMonday = firstDayOfYear.subtract(Duration(days: daysOffset));
    return ((date.difference(firstMonday).inDays) / 7).ceil() + 1;
  }

  void _nextWeek() {
    setState(() {
      _startOfWeek = _startOfWeek.add(const Duration(days: 7));
      _endOfWeek = _startOfWeek.add(const Duration(days: 4));
    });
  }

  void _previousWeek() {
    setState(() {
      _startOfWeek = _startOfWeek.subtract(const Duration(days: 7));
      _endOfWeek = _startOfWeek.add(const Duration(days: 4));
    });
  }

  // ---------- Gestion  de subPlace ----------
  String formatSubPlace(dynamic subPlace) {
    if (subPlace == null) return '';

    if (subPlace is List) {
      final filtered = subPlace
          .where((e) => e != null && e.toString().trim().isNotEmpty)
          .toList();
      if (filtered.isEmpty) return '';
      return filtered.join(', ');
    }

    if (subPlace is String && subPlace.trim().isNotEmpty) return subPlace;

    return '';
  }

  // ---------- récuperer le nom des travailleurs ----------
  String getWorkerNames(List<String> ids) {
    return ids.map((id) => _workersMap[id] ?? 'Inconnu').join(', ');
  }

   //------------ construction scroll et chevron dans les cellules
 Widget buildScrollableCell(List<Map<String, dynamic>> events) {
  final scrollController = ScrollController();
  bool showChevron = false;

  // 🔹 1. Grouper les événements par lieu
  final Map<String, List<Map<String, dynamic>>> groupedByPlace = {};
  for (var e in events) {
    final place = e['place'] ?? 'Inconnu';
    groupedByPlace.putIfAbsent(place, () => []).add(e);
  }

  // 🔹 2. Trier les lieux par ordre alphabétique (optionnel)
  final sortedPlaces = groupedByPlace.keys.toList()..sort();

  // 🔹 3. Fonction pour générer une couleur stable à partir du nom du lieu
  Color getColorForPlace(String place) {
    final base = place.hashCode.abs();
    final color = Colors.primaries[base % Colors.primaries.length];
    return color.shade200;
  }

  return StatefulBuilder(
    builder: (context, setInnerState) {
      scrollController.addListener(() {
        final maxScroll = scrollController.position.maxScrollExtent;
        final current = scrollController.offset;
        final shouldShow = current < maxScroll;
        if (shouldShow != showChevron) {
          setInnerState(() => showChevron = shouldShow);
        }
      });

      return Stack(
        children: [
          Scrollbar(
            controller: scrollController,
            thumbVisibility: true,
            thickness: 4,
            radius: const Radius.circular(4),
            trackVisibility: true,
            child: ListView(
              controller: scrollController,
              children: [
                for (final place in sortedPlaces) ...[
                  // 🔸 Liste des événements de ce lieu
                  ...groupedByPlace[place]!.map((e) {
                    // on peut réutiliser la même couleur pour cohérence
                    final color = getColorForPlace(place);
                    return Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      child: buildEventCell(e),
                    );
                  }),

                  const Divider(height: 10),
                ],
              ],
            ),
          ),
          if (showChevron)
            const Positioned(
              bottom: 2,
              left: 0,
              right: 0,
              child: Center(
                child: Icon(
                  Icons.arrow_circle_down_sharp,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ),
        ],
      );
    },
  );
}

  //------------ construction des cellules ----------------
 Widget buildEventCell(Map<String, dynamic> e) {
  final sub = formatSubPlace(e['subPlace']);
  final workerNames = getWorkerNames(e['workerIds']);
  final place = e['place'] ?? 'Inconnu';

  // Couleur cohérente par lieu
  final baseColor = _colorForPlace(place);

  // Pastille visible uniquement si isWeeklyTask == false
  final bool showDot = e['isWeeklyTask'] == false;

  return InkWell(
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventFormPage(eventId: e['id'])),
    ),
    child: Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('• $place',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
              if (showDot)
                Container(
                  width: 10, height: 10, margin: const EdgeInsets.only(left: 4),
                  decoration: const BoxDecoration(color: Colors.purple, shape: BoxShape.circle),
                ),
            ],
          ),
          if (sub.isNotEmpty) Text(' - $sub', style: const TextStyle(fontSize: 12, color: Colors.black87)),
          if (workerNames.isNotEmpty) const Text('Travailleurs:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
          if (workerNames.isNotEmpty) Text(workerNames, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
          if (e['task'] != null && e['task'] != '') Text('Tâche: ${e['task']}', style: const TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

  // ---------- Build Widget ----------
  @override
  Widget build(BuildContext context) {
    final title = 'S.$_weekNumber — du ${DateFormat('dd/MM').format(_startOfWeek)} au ${DateFormat('dd/MM').format(_endOfWeek)}';

    return StreamBuilder(
      stream: FirebaseFirestore.instance.collection('events')
        .where('day',isGreaterThanOrEqualTo: Timestamp.fromDate(
          DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day),),
        )
        .where('day', isLessThanOrEqualTo: Timestamp.fromDate(DateTime(
              _endOfWeek.year,
              _endOfWeek.month,
              _endOfWeek.day,
              23,
              59,
              59,
            ),
          ),
        ).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final events = snapshot.data!.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'day': (data['day'] as Timestamp).toDate(),
            'timeSlot': data['timeSlot'],
            'place': data['place'],
            'subPlace': data['subPlace'],
            'task': data['task'],
            'workerIds': List<String>.from(data['workerIds'] ?? []),
          };
        }).toList();

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
          onPressed: (){
            _scheduleController.showDialogGeneratedWeeklyScheduleType(
      context: context,
      selectedDate: _startOfWeek, // ta semaine courante
      weekNumber: _weekNumber,// ou false si poussière
            );
          }, 
          icon: Icon(
            Icons.calendar_view_week_rounded, 
            color: Colors.green,),
        ),
            title: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.picture_as_pdf,
                    color: Colors.redAccent,
                  ),
                  tooltip: 'Voir les PDF enregistrés',
                  onLongPress: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Exporter en PDF'),
                        content: Text('Voulez-vous générer le PDF du planning de la semaine $_weekNumber ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Confirmer'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await PdfController.generateWeeklyPdf(
                        events: events,
                        workersMap: _workersMap,
                        weekNumber: _weekNumber,
                      );

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(
                            'PDF généré pour la semaine $_weekNumber ✅')),
                        );
                      }
                    }
                  },
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ListPdfScheduleWeeklyPage()),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(34, 255, 82, 82),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: _previousWeek,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _nextWeek,
              ),
            ],
          ),
          body: FutureBuilder<List<Map<String, dynamic>>>(
            future: _scheduleController.loadAllEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allEvents = snapshot.data!;
              Map<String, List<Map<String, dynamic>>> grouped = {};
              for (var e in allEvents) {
                final key = '${DateFormat('yyyy-MM-dd').format(e['day'])}_${e['timeSlot']}';
                grouped.putIfAbsent(key, () => []).add(e);
              }

              return InteractiveViewer(
                panEnabled: true,
                scaleEnabled: true,
                minScale: 0.5,
                maxScale: 2.0,
                constrained: false,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ---------- HEADER : jours + dates ----------
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 70,
                            child: Image.asset('assets/icon/app_icon.png', width: 50, height: 50,),
                          ), // espace pour la colonne MATIN/APRÈS-MIDI
                          ..._weekDays.map(
                            (d) {
                              final dayName = DateFormat('EEEE', 'fr_FR').format(d).toUpperCase();
                              final dayNumber = DateFormat('d').format(d);

                              return Container(
                                width: 180, // même largeur que les colonnes
                                height: 50,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: const Color.fromARGB(34, 255, 82, 82),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                alignment: Alignment.center,
                                child: RichText(
                                  textAlign: TextAlign.center,
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '$dayName ',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black,
                                          fontSize: 16,
                                        ),
                                      ),
                                      TextSpan(
                                        text: dayNumber,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.indigo,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // ---------- TABLE MATIN / APRÈS-MIDI ----------
                      for (var slot in ['morning', 'afternoon'])
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 70,
                              height: 600,
                              decoration: BoxDecoration(
                                color: const Color.fromARGB(34, 255, 82, 82),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Transform.rotate(
                                  angle: -3.14 / 2,
                                  child: Text(
                                    slot == 'morning' ? 'MATIN' : 'APRÈS-MIDI',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            ..._weekDays.map((day) {
                              final key = '${DateFormat('yyyy-MM-dd').format(day)}_$slot';
                              final cellEvents = grouped[key] ?? [];

                              return Container(
                                width: 180, // identique à la largeur du header
                                height: 600,
                                margin: const EdgeInsets.all(2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: slot == 'morning'
                                      ? Colors.blue.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: cellEvents.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '—',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      )
                                    : buildScrollableCell(cellEvents),
                              );
                            }),
                          ],
                        ),
                    ],
                  )

                ),
              );
            },
          ),
        );
      },
    );
  }
}
