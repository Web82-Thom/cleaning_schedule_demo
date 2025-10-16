import 'package:cleaning_schedule/controllers/rdv_controller.dart';
import 'package:cleaning_schedule/models/rdv_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RdvFormPage extends StatefulWidget {
  final RdvModel? rdvData;
  final DateTime? initialDate;
  final Map<String, String>? workersMap;

  const RdvFormPage({this.rdvData, this.initialDate, this.workersMap, Key? key})
    : super(key: key);

  @override
  State<RdvFormPage> createState() => _RdvFormPageState();
}

class _RdvFormPageState extends State<RdvFormPage> {
  final _formKey = GlobalKey<FormState>();
  final RdvController _controller = RdvController();
  final user = FirebaseAuth.instance.currentUser;

  DateTime? selectedDate;
  String motif = '';
  String lieu = '';
  String? selectedWorkerId;
  bool isTeam = false;

  late final Map<String, String> workersMap;

  @override
  void initState() {
    super.initState();
    selectedDate = widget.rdvData?.date ?? widget.initialDate;
    motif = widget.rdvData?.motif ?? '';
    lieu = widget.rdvData?.lieu ?? '';
    selectedWorkerId = widget.rdvData?.workerId;
    isTeam = selectedWorkerId == 'TEAM';
    workersMap = widget.workersMap ?? {};
    if (isTeam) selectedWorkerId = null;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.rdvData == null ? 'Créer un RDV' : 'Modifier un RDV',
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Date & heure
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Date & heure',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  validator: (_) =>
                      selectedDate == null ? 'Sélectionnez une date' : null,
                  controller: TextEditingController(
                    text: selectedDate != null
                        ? DateFormat('dd/MM/yyyy HH:mm').format(selectedDate!)
                        : '',
                  ),
                  onTap: () async {
                    final now = DateTime.now();
                    final initial =
                        (selectedDate != null && !selectedDate!.isBefore(now))
                        ? selectedDate!
                        : now;

                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: now,
                      lastDate: DateTime(2100),
                    );

                    if (pickedDate != null) {
                      final pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(
                          selectedDate ?? now,
                        ),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedDate = DateTime(
                            pickedDate.year,
                            pickedDate.month,
                            pickedDate.day,
                            pickedTime.hour,
                            pickedTime.minute,
                          );
                        });
                      }
                    }
                  },
                ),
                const SizedBox(height: 12),

                // Motif
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Motif'),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Champ requis' : null,
                  initialValue: motif,
                  onChanged: (value) => motif = value,
                ),
                const SizedBox(height: 12),

                // Lieu
                TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Lieu (optionnel)',
                  ),
                  initialValue: lieu,
                  onChanged: (value) => lieu = value,
                ),
                const SizedBox(height: 12),

                // Équipe
                CheckboxListTile(
                  title: const Text('Équipe'),
                  value: isTeam,
                  onChanged: (value) {
                    setState(() {
                      isTeam = value ?? false;
                      if (isTeam) selectedWorkerId = null;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // Travailleur
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Travailleur',
                    border: OutlineInputBorder(),
                  ),
                  isExpanded: true,
                  items: workersMap.entries
                      .map(
                        (e) => DropdownMenuItem<String>(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  value: isTeam ? null : selectedWorkerId,
                  onChanged: isTeam
                      ? null
                      : (value) {
                          setState(() => selectedWorkerId = value);
                        },
                  validator: (value) =>
                      (!isTeam && (value == null || value.isEmpty))
                      ? 'Sélectionnez un travailleur'
                      : null,
                ),
                const SizedBox(height: 20),

                // Enregistrer
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate() &&
                        selectedDate != null &&
                        (isTeam || selectedWorkerId != null)) {
                      final rdv = RdvModel(
                        id: widget.rdvData?.id ?? '',
                        instructorId: user!.uid,
                        date: selectedDate!,
                        heure: DateFormat('HH:mm').format(selectedDate!),
                        motif: motif,
                        lieu: lieu,
                        workerId: isTeam ? 'TEAM' : selectedWorkerId!,
                        createdAt: Timestamp.now(),
                      );

                      await _controller.saveRdv(context, rdv);

                      Navigator.pop(
                        context,
                        true,
                      ); // ← renvoyer true pour recharger
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
