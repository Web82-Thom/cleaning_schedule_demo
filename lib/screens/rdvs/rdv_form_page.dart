import 'package:cleaning_schedule_demo/controllers/auth_controller.dart';
import 'package:cleaning_schedule_demo/controllers/rdv_controller.dart';
import 'package:cleaning_schedule_demo/models/rdv_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RdvFormPage extends StatefulWidget {
  final RdvModel? rdvData;
  final DateTime? initialDate;
  final Map<String, String>? workersMap;
  final Map<String, String>? monitorsMap;

  const RdvFormPage({
    this.rdvData,
    this.initialDate,
    this.workersMap,
    this.monitorsMap,
    super.key,
  });

  @override
  State<RdvFormPage> createState() => _RdvFormPageState();
}

class _RdvFormPageState extends State<RdvFormPage> {
  final _formKey = GlobalKey<FormState>();
  final RdvController _controller = RdvController();
  final AuthController _authController = AuthController();
  final user = FirebaseAuth.instance.currentUser;

  DateTime? selectedDate;
  String motif = '';
  String lieu = '';
  String? selectedWorkerId;
  bool isTeam = false;

  Map<String, String> workersMap = {};
  Map<String, String> monitorsMap = {};
  List<String> selectedMonitorIds = [];
  List<String> selectedWorkerIds = []; // 🔹 multi-travailleurs

  @override
  void initState() {
    super.initState();

    selectedDate = widget.rdvData?.date ?? widget.initialDate;
    motif = widget.rdvData?.motif ?? '';
    lieu = widget.rdvData?.lieu ?? '';
    selectedWorkerId = widget.rdvData?.workerId;
    selectedMonitorIds = widget.rdvData?.monitorIds ?? [];
    selectedWorkerIds = widget.rdvData?.workerIds ?? [];

    workersMap = widget.workersMap ?? {};
    monitorsMap = widget.monitorsMap ?? {};
    isTeam = selectedWorkerId == 'TEAM';

    // 🔹 rétro-compat : si pas TEAM, mais workerId seul, on alimente la liste
    if (!isTeam && (selectedWorkerId != null && selectedWorkerId!.isNotEmpty && selectedWorkerIds.isEmpty)) {
      selectedWorkerIds = [selectedWorkerId!];
    }

    if (isTeam) {
      selectedWorkerId = null;
    }

    if (monitorsMap.isEmpty) {
      _loadMonitors();
    }
  }

  Future<void> _loadMonitors() async {
    monitorsMap = await _authController.loadMonitorsMap();
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Tri alphabétique des travailleurs par nom
    final sortedWorkerEntries = workersMap.entries.toList()
      ..sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));

    // 🔹 pour "Toute l'équipe"
    final allWorkerIds = sortedWorkerEntries.map((e) => e.key).toList();
    final bool isAllTeamSelected = isTeam &&
        allWorkerIds.isNotEmpty &&
        selectedWorkerIds.toSet().containsAll(allWorkerIds);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              widget.rdvData == null ? 'Créer un RDV' : 'Modifier un RDV'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // 🗓️ Date
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (_) =>
                      selectedDate == null ? 'Sélectionnez une date' : null,
                  controller: TextEditingController(
                    text: selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(selectedDate!)
                        : '',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final initial = selectedDate ?? now;

                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100),
                    );

                    if (pickedDate != null) {
                      setState(() {
                        final oldTime = TimeOfDay.fromDateTime(selectedDate ?? now);
                        selectedDate = DateTime(
                          pickedDate.year,
                          pickedDate.month,
                          pickedDate.day,
                          oldTime.hour,
                          oldTime.minute,
                        );
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),

                // ⏰ Heure
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Heure',
                    suffixIcon: Icon(Icons.access_time),
                  ),
                  validator: (_) =>
                      selectedDate == null ? 'Sélectionnez une heure' : null,
                  controller: TextEditingController(
                    text: selectedDate != null
                        ? DateFormat('HH:mm').format(selectedDate!)
                        : '',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final initialTime = TimeOfDay.fromDateTime(selectedDate ?? now);
                    final pickedTime = await showTimePicker(
                      context: context,
                      initialTime: initialTime,
                    );

                    if (pickedTime != null) {
                      setState(() {
                        final oldDate = selectedDate ?? now;
                        selectedDate = DateTime(
                          oldDate.year,
                          oldDate.month,
                          oldDate.day,
                          pickedTime.hour,
                          pickedTime.minute,
                        );
                      });
                    }
                  },
                ),

                const SizedBox(height: 12),

                // 🧾 Motif
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Motif'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                  initialValue: motif,
                  onChanged: (value) => motif = value,
                ),
                const SizedBox(height: 12),

                // 📍 Lieu
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Lieu (optionnel)'),
                  initialValue: lieu,
                  onChanged: (value) => lieu = value,
                ),
                const SizedBox(height: 12),

                // 👥 Équipe
                CheckboxListTile(
                  title: const Text('Équipe'),
                  value: isTeam,
                  onChanged: (value) {
                    setState(() {
                      isTeam = value ?? false;
                      if (isTeam) {
                        selectedWorkerId = null;
                        // on laisse selectedWorkerIds tel quel (équipe déjà pré-sélectionnée éventuelle)
                      } else {
                        // repasse en mode travailleur seul
                        if (selectedWorkerIds.length == 1) {
                          selectedWorkerId = selectedWorkerIds.first;
                        } else {
                          selectedWorkerId = null;
                          selectedWorkerIds = [];
                        }
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),

                // 👷‍♂️ Travailleur (mode individuel)
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Travailleur',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  initialValue: (!isTeam && 
                    selectedWorkerId != null &&
                    selectedWorkerId!.isNotEmpty &&
                    workersMap.containsKey(selectedWorkerId))
                      ? selectedWorkerId
                      : null,
                  items: [
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Aucun / Sélectionner'),
                    ),
                    ...sortedWorkerEntries.map(
                      (e) => DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    ),
                  ],
                  onChanged: isTeam
                      ? null
                      : (value) {
                          setState(() {
                            selectedWorkerId = value;
                            selectedWorkerIds = [];
                            if (value != null && value.isNotEmpty) {
                              selectedWorkerIds = [value];
                            }
                          });
                        },
                  validator: (value) {
                    if (!isTeam &&
                        selectedMonitorIds.isEmpty &&
                        (value == null || value.isEmpty)) {
                      return 'Sélectionnez un travailleur ou un moniteur';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // 👥 Multi-sélection quand mode équipe
                if (isTeam && workersMap.isNotEmpty) ...[
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Travailleurs de l’équipe',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  // 🔹 TOUTE L’ÉQUIPE
                  CheckboxListTile(
                    title: const Text('Toute l’équipe'),
                    value: isAllTeamSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedWorkerIds = List<String>.from(allWorkerIds);
                        } else {
                          selectedWorkerIds.clear();
                        }
                      });
                    },
                  ),
                  Column(
                    children: sortedWorkerEntries.map((entry) {
                      final id = entry.key;
                      final name = entry.value;
                      final isSelected = selectedWorkerIds.contains(id);

                      return CheckboxListTile(
                        title: Text(name),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              if (!selectedWorkerIds.contains(id)) {
                                selectedWorkerIds.add(id);
                              }
                            } else {
                              selectedWorkerIds.remove(id);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // 🎓 Moniteurs associés
                if (monitorsMap.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Moniteurs associés',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...monitorsMap.entries.map(
                      (entry) => CheckboxListTile(
                        title: Text(entry.value),
                        value: selectedMonitorIds.contains(entry.key),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              if (!selectedMonitorIds.contains(entry.key)) {
                                selectedMonitorIds.add(entry.key);
                              }
                            } else {
                              selectedMonitorIds.remove(entry.key);
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // 💾 Enregistrer
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() &&
                        selectedDate != null) {
                      final rdv = RdvModel(
                        id: widget.rdvData?.id ?? '',
                        instructorId: user!.uid,
                        date: selectedDate!,
                        heure: DateFormat('HH:mm').format(selectedDate!),
                        motif: motif,
                        lieu: lieu,
                        workerId: isTeam ? 'TEAM' : (selectedWorkerId ?? ''),
                        workerIds: isTeam
                            ? selectedWorkerIds
                            : ((selectedWorkerId != null &&
                                    selectedWorkerId!.isNotEmpty)
                                ? [selectedWorkerId!]
                                : <String>[]),
                        monitorIds: selectedMonitorIds,
                        createdAt: Timestamp.now(),
                      );

                      await _controller.saveRdv(context, rdv);
                      if (context.mounted) Navigator.pop(context, true);
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
