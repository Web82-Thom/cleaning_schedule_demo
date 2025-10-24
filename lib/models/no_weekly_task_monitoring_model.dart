import 'package:cloud_firestore/cloud_firestore.dart';

class NoWeeklyTaskMonitoringModel {
  final String id;
  final DateTime day;
  final String timeSlot;
  final String place;
  final String? subPlace;
  final String task;
  final List<String> workerIds;
  final Timestamp createdAt;
  final int weekNumber;
  final bool isWeeklyTask;
  final bool isReprogrammed;

  NoWeeklyTaskMonitoringModel({
    required this.id,
    required this.day,
    required this.timeSlot,
    required this.place,
    this.subPlace,
    required this.task,
    required this.workerIds,
    required this.createdAt,
    required this.weekNumber,
    required this.isWeeklyTask,
    required this.isReprogrammed,
  });

  /// 🔹 Conversion vers Firestore
  Map<String, dynamic> toFirestore() => {
        'day': Timestamp.fromDate(day),
        'timeSlot': timeSlot,
        'place': place,
        'subPlace': subPlace,
        'task': task,
        'workerIds': workerIds,
        'createdAt': createdAt == Timestamp.now()
            ? FieldValue.serverTimestamp()
            : createdAt,
        'weekNumber': weekNumber,
        'isWeeklyTask': isWeeklyTask,
        'isReprogrammed': isReprogrammed,
      }..removeWhere((key, value) => value == null);

  /// 🔹 Restauration depuis Firestore
  factory NoWeeklyTaskMonitoringModel.fromFirestore(
      String id, Map<String, dynamic> data) {
    final tsDay = data['day'] as Timestamp?;
    final tsCreated = data['createdAt'] as Timestamp?;
    return NoWeeklyTaskMonitoringModel(
      id: id,
      day: tsDay?.toDate() ?? DateTime.now(),
      timeSlot: data['timeSlot'] ?? '',
      place: data['place'] ?? '',
      subPlace: data['subPlace'],
      task: data['task'] ?? '',
      workerIds: List<String>.from(data['workerIds'] ?? []),
      createdAt: tsCreated ?? Timestamp.now(),
      weekNumber: data['weekNumber'] ?? 0,
      isWeeklyTask: data['isWeeklyTask'] ?? false,
      isReprogrammed: data['isReprogrammed'] ?? false,
    );
  }
}
