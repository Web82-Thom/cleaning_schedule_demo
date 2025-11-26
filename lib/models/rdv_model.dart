import 'package:cloud_firestore/cloud_firestore.dart';

class RdvModel {
  final String id;
  final String instructorId; // Moniteur qui a créé le RDV
  final String workerId;     // Travailleur assigné ou "TEAM"
  final List<String> workerIds; // 🔹 NOUVEAU : liste de travailleurs (multi-sélection)
  final DateTime date;
  final String motif;
  final String? lieu;
  final String heure;
  final Timestamp createdAt;
  final List<String> monitorIds; // Liste des moniteurs associés

  RdvModel({
    required this.id,
    required this.instructorId,
    required this.workerId,
    required this.workerIds,
    required this.date,
    required this.motif,
    required this.heure,
    this.lieu,
    required this.createdAt,
    required this.monitorIds,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'instructorId': instructorId,
      'workerId': workerId,
      'workerIds': workerIds, // 🔹 on enregistre aussi la liste
      'date': Timestamp.fromDate(date),
      'motif': motif,
      'lieu': lieu ?? '',
      'heure': heure,
      'createdAt': createdAt,
      'monitorIds': monitorIds,
    };
  }

  factory RdvModel.fromFirestore(String id, Map<String, dynamic> data) {
    // 🔹 Récupère le workerId "historique"
    final String rawWorkerId = data['workerId']?.toString() ?? '';

    // 🔹 Récupère la liste de travailleurs (si déjà présente)
    final List<String> rawWorkerIds = (data['workerIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    // 🔹 Rétro-compat :
    // si workerIds est vide mais qu'on a un workerId non vide et ≠ "TEAM",
    // on l'ajoute dans la liste pour uniformiser.
    final List<String> normalizedWorkerIds = rawWorkerIds.isNotEmpty
        ? rawWorkerIds
        : ((rawWorkerId.isNotEmpty && rawWorkerId != 'TEAM')
            ? <String>[rawWorkerId]
            : <String>[]);

    return RdvModel(
      id: id,
      instructorId: data['instructorId']?.toString() ?? '',
      workerId: rawWorkerId,
      workerIds: normalizedWorkerIds,
      date: (data['date'] as Timestamp).toDate(),
      motif: data['motif']?.toString() ?? '',
      lieu: data['lieu']?.toString() ?? '',
      heure: data['heure']?.toString() ?? '',
      createdAt: data['createdAt'] is Timestamp
          ? data['createdAt'] as Timestamp
          : Timestamp.now(),
      monitorIds:
          (data['monitorIds'] as List?)?.map((e) => e.toString()).toList() ??
              [],
    );
  }

  RdvModel copyWith({
    String? id,
    String? instructorId,
    String? workerId,
    List<String>? workerIds,
    DateTime? date,
    String? motif,
    String? lieu,
    String? heure,
    Timestamp? createdAt,
    List<String>? monitorIds,
  }) {
    return RdvModel(
      id: id ?? this.id,
      instructorId: instructorId ?? this.instructorId,
      workerId: workerId ?? this.workerId,
      workerIds: workerIds ?? this.workerIds,
      date: date ?? this.date,
      motif: motif ?? this.motif,
      lieu: lieu ?? this.lieu,
      heure: heure ?? this.heure,
      createdAt: createdAt ?? this.createdAt,
      monitorIds: monitorIds ?? this.monitorIds,
    );
  }

  String get displayLabel {
    final lieuPart = (lieu != null && lieu!.isNotEmpty) ? ' • $lieu' : '';
    return '$motif$lieuPart';
  }
}
