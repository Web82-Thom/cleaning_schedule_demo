import 'dart:io';
import 'package:cleaning_schedule/screens/list_pdf_page.dart';
import 'package:cleaning_schedule/screens/planning/event_from_page.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

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
  Map<String, String> _workersMap = {}; // workerId → workerName
  int get _weekNumber => _getWeekNumber(_startOfWeek);


  @override
  void initState() {
    super.initState();
    _startOfWeek = _getStartOfWeek(widget.initialWeek);
    _endOfWeek = _startOfWeek.add(const Duration(days: 4));
    _loadWorkers();
  }

  // ---------- Gestion des workers ----------
  Future<void> _loadWorkers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('workers')
        .where('active', isEqualTo: true)
        .get();
    if (!mounted) return;

    setState(() {
      _workersMap = {
        for (var doc in snapshot.docs)
          doc.id: '${doc['firstName']} ${doc['name']}',
      };
    });
  }

  // ---------- Semaine ----------
  DateTime _getStartOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  List<DateTime> get _weekDays =>
      List.generate(5, (i) => _startOfWeek.add(Duration(days: i)));

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

  // ---------- Gestion safe de subPlace ----------
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

  // ---------- Chargement de tous les events ----------
  Future<List<Map<String, dynamic>>> _loadAllEvents() async {
    final eventsSnapshot = await FirebaseFirestore.instance
        .collection('events')
        .get();
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
        'isNoWeekly': false,
      };
    }).toList();

    final noWeeklySnapshot = await FirebaseFirestore.instance
        .collection('eventsNoWeekly')
        .get();
    final noWeeklyEvents = noWeeklySnapshot.docs.map((doc) {
      final data = doc.data();
      dynamic subPlace = data['subPlace'];
      subPlace ??= <String>[];
      if (subPlace is String) {
        if (subPlace.trim().isEmpty || subPlace.trim() == '[]') {
          subPlace = [];
        } else {
          subPlace = [subPlace];
        }
      } else if (subPlace is! List){
          subPlace = [];
        }
      return {
        'id': doc.id,
        'day': (data['day'] as Timestamp).toDate(),
        'timeSlot': data['timeSlot'] ?? 'morning',
        'place': data['place'] ?? '',
        'subPlace': subPlace,
        'task': data['task'] ?? '',
        'workerIds': List<String>.from(data['workerIds'] ?? []),
        'isNoWeekly': true,
      };
    }).toList();

    return [...events, ...noWeeklyEvents];
  }

  // ---------- Génération PDF ----------
  Future<void> generateWeeklyPdf(List<Map<String, dynamic>> events) async {
    final pdf = pw.Document();
    final days = _weekDays;

    // Grouper par jour + créneau
    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var e in events) {
      final key = '${DateFormat('yyyy-MM-dd').format(e['day'])}_${e['timeSlot']}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    const int maxEventsPerCell = 6; // max d'événements affichés par page pour une cellule

    pw.Widget buildEventList(List<Map<String, dynamic>> list, int startIndex) {
      if (list.isEmpty) return pw.Text('—', style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10));
      final sublist = list.skip(startIndex).take(maxEventsPerCell).toList();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: sublist.map((e) {
          final workers = (e['workerIds'] as List)
              .map((id) => _workersMap[id] ?? 'Inconnu')
              .join(', ');

          final subPlace = e['subPlace'] != null && e['subPlace'] != '' ? ' (${e['subPlace']})' : '';
          final task = e['task'] != null && e['task'] != '' ? ' • ${e['task']}' : '';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                e['place'] ?? 'Lieu inconnu',
                style:  pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.blue800, fontSize: 11),
              ),
              if (subPlace.isNotEmpty)
                pw.Text(
                  subPlace,
                  style: const pw.TextStyle(color: PdfColors.indigo, fontSize: 10),
                ),
              if (task.isNotEmpty)
                pw.Text(
                  task,
                  style: const pw.TextStyle(color: PdfColors.deepPurple, fontSize: 10),
                ),
              pw.Text(
                'Travailleurs : $workers',
                style: const pw.TextStyle(color: PdfColors.grey800, fontSize: 9),
              ),
              pw.SizedBox(height: 4),
            ],
          );
        }).toList(),
      );
    }

    for (var slot in ['morning', 'afternoon']) {
      int maxChunks = 1;
      Map<String, int> dayChunks = {};
      for (var day in days) {
        final key = '${DateFormat('yyyy-MM-dd').format(day)}_$slot';
        final count = grouped[key]?.length ?? 0;
        final chunks = (count / maxEventsPerCell).ceil();
        dayChunks[key] = chunks;
        if (chunks > maxChunks) maxChunks = chunks;
      }

      for (int chunkIndex = 0; chunkIndex < maxChunks; chunkIndex++) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (context) {
              return [
                pw.Text(
                  '${slot == 'morning' ? 'MATIN' : 'APRÈS-MIDI'} - Semaine $_weekNumber',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: slot == 'morning' ? PdfColors.orange800 : PdfColors.teal800,
                  ),
                ),
                pw.SizedBox(height: 10),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                  columnWidths: {
                    for (int i = 0; i < days.length; i++) i: const pw.FlexColumnWidth()
                  },
                  children: [
                    // Ligne des jours
                    pw.TableRow(
                      children: days.map((day) {
                        final label = DateFormat('EEEE', 'fr_FR').format(day).toUpperCase();
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: pw.Center(
                            child: pw.Text(
                              label,
                              style:  pw.TextStyle(
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.green,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    // Ligne des événements
                    pw.TableRow(
                      children: days.map((day) {
                        final key = '${DateFormat('yyyy-MM-dd').format(day)}_$slot';
                        final eventsForDay = grouped[key] ?? [];
                        return pw.Padding(
                          padding: const pw.EdgeInsets.all(4),
                          child: buildEventList(eventsForDay, chunkIndex * maxEventsPerCell),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ];
            },
          ),
        );
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = 'planning_week_$_weekNumber.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await OpenFilex.open(file.path);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF généré : $fileName ✅')),
      );
    }
  }

  // ---------- Build Widget ----------
  @override
  Widget build(BuildContext context) {
    final title =
        'Semaine $_weekNumber — du ${DateFormat('dd/MM').format(_startOfWeek)} au ${DateFormat('dd/MM').format(_endOfWeek)}';

    return StreamBuilder(
      stream: FirebaseFirestore.instance
          .collection('events')
          .where(
            'day',
            isGreaterThanOrEqualTo: Timestamp.fromDate(
              DateTime(_startOfWeek.year, _startOfWeek.month, _startOfWeek.day),
            ),
          )
          .where(
            'day',
            isLessThanOrEqualTo: Timestamp.fromDate(
              DateTime(
                _endOfWeek.year,
                _endOfWeek.month,
                _endOfWeek.day,
                23,
                59,
                59,
              ),
            ),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());

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
                        title: const Text(
                          'Exporter en PDF',
                          style: TextStyle(fontSize: 14),
                        ),
                        content: Text(
                          'Voulez-vous générer le PDF du planning de la semaine $_weekNumber ?',
                        ),
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
                    if (confirmed == true) generateWeeklyPdf(events);
                  },
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ListPdfPage()),
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
            future: _loadAllEvents(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              final allEvents = snapshot.data!;
              Map<String, List<Map<String, dynamic>>> grouped = {};
              for (var e in allEvents) {
                final key =
                    '${DateFormat('yyyy-MM-dd').format(e['day'])}_${e['timeSlot']}';
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
                      Row(
                        children: [
                          const SizedBox(width: 40),
                          ..._weekDays.map(
                            (d) => Container(
                              width: 180,
                              alignment: Alignment.center,
                              padding: const EdgeInsets.all(8),
                              child: Text(
                                DateFormat(
                                  'EEEE',
                                  'fr_FR',
                                ).format(d).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (var period in ['morning', 'afternoon'])
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 70, // largeur fixe de la colonne
                              height: 330, // hauteur fixe de la colonne
                              color: Colors.grey.shade300,
                              child: Center(
                                child: Transform.rotate(
                                  angle: -3.14 / 2, // rotation 90° CCW
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: Text(
                                      period == 'morning' ? 'MATIN' : 'APRÈS-MIDI',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14, // taille initiale
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            ..._weekDays.map((day) {
                              final key =
                                  '${DateFormat('yyyy-MM-dd').format(day)}_$period';
                              final cellEvents = grouped[key] ?? [];

                              return Container(
                                width: 180,
                                height: 330,
                                margin: const EdgeInsets.all(2),
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: period == 'morning'
                                      ? Colors.blue.shade100
                                      : Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: cellEvents.isEmpty
                                    ? const Center(
                                        child: Text(
                                          '—',
                                          style: TextStyle(
                                            color: Colors.black54,
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        children: cellEvents.map((e) {
                                          final sub = formatSubPlace(
                                            e['subPlace'],
                                          );
                                          final workerNames =
                                              (e['workerIds'] as List)
                                                  .map(
                                                    (id) =>
                                                        _workersMap[id] ??
                                                        'Inconnu',
                                                  )
                                                  .join(', ');
                                          final place = e['place'] ?? 'Inconnu';
                                          final baseColor =
                                              e['isNoWeekly'] == true
                                              ? Colors.purple.shade100
                                              : Colors
                                                    .primaries[place.hashCode %
                                                        Colors.primaries.length]
                                                    .shade200;

                                          return InkWell(
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (_) => EventFormPage(
                                                    eventId: e['id'],
                                                  ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: baseColor,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: Colors.black12,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    '• $place',
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                  if (sub.isNotEmpty)
                                                    Text(
                                                      ' - $sub',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        color: Colors.black87,
                                                      ),
                                                    ),
                                                  if (workerNames.isNotEmpty)
                                                    const Text(
                                                      'Travailleurs:',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  if (workerNames.isNotEmpty)
                                                    Text(
                                                      workerNames,
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  if (e['task'] != null &&
                                                      e['task'] != '')
                                                    Text(
                                                      'Tâche: ${e['task']}',
                                                      style: const TextStyle(
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              );
                            }).toList(),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
