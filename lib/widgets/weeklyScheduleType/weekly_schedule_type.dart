// weekly_schedule_type.dart
//
// Planning type centralisé (lundi → vendredi)
// - Semaine "normale"  : isWeeklyTask = true, task = ''
// - Semaine "poussière": isWeeklyTask = false, task = 'Poussières'
//
// Lieux utilisés : "Hôtel", "Le T5", "Foyer d'hébergement"
//
// Utilisation côté controller :
//   final eventsLundi = generateDayTypeEvents(
//     dayName: 'monday',
//     dayDate: someMondayDate,
//     weekNumber: 42,
//     dustWeek: false, // true => semaine poussière
//   );
//
//   final eventsSemaine = generateWeekTypeEvents(
//     mondayDate: someMondayDate,
//     weekNumber: 42,
//     dustWeek: true,
//   );
//
// Ensuite: envoi vers Firestore avec .add() / .batch()

import 'package:cloud_firestore/cloud_firestore.dart';

/// Jours supportés
const _daysOrder = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday'];

/// ------------------------------
/// 🗓️ DÉFINITIONS DU PLANNING TYPE
/// ------------------------------
/// Chaque jour possède une liste d'items { place, timeSlot }
/// timeSlot ∈ {'morning', 'afternoon'}

final Map<String, List<Map<String, String>>> kWeeklyType = {
  // ✅ Semaine normale (hebdo)
  'monday': [
    //----Matin----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Tignol negrepelisse magasin', 'timeSlot': 'morning'},
    {'place': 'Tignol negrepelisse maison', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'SAVS', 'timeSlot': 'afternoon'},
    {'place': 'Tignol monclarc de Quercy', 'timeSlot': 'afternoon'},
    {'place': 'Club House', 'timeSlot': 'afternoon'},
    {'place': 'Centre équestre', 'timeSlot': 'afternoon'},
    {'place': 'Blanchisserie', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
  ],
  'tuesday': [
    //----Matin----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Médico social', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Le T5', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'Tignol negrepelisse maison', 'timeSlot': 'afternoon'},
    {'place': 'Tignol Vaissac', 'timeSlot': 'afternoon'},
  ],
  'wednesday': [
    //----Matin----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Bureau Administration', 'timeSlot': 'morning'},
    {'place': 'Salle de sport', 'timeSlot': 'morning'},

    //----Après-midi----
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Bureau Administration', 'timeSlot': 'afternoon'},
    {'place': 'Tignol negrepelisse magasin', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
  ],
  'thursday': [
    //----Matin----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Appart Bruno', 'timeSlot': 'morning'},
    {'place': 'Espace vert', 'timeSlot': 'morning'},
    {'place': 'Multi services', 'timeSlot': 'morning'},
    {'place': 'Centre équestre', 'timeSlot': 'morning'},
    {'place': 'Atelier', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'afternoon'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
  ],
  'friday': [
    //----Matin----
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer d\'hébergement', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Bureau Administration', 'timeSlot': 'morning'},
    {'place': 'Tignol negrepelisse magasin', 'timeSlot': 'morning'},
    {'place': 'CSE', 'timeSlot': 'morning'},
    {'place': 'Blanchisserie', 'timeSlot': 'morning'},
    {'place': 'Centre équestre', 'timeSlot': 'morning'},
    {'place': 'Chateau', 'timeSlot': 'morning'},
    
  ],
};

final Map<String, List<Map<String, String>>> kDustType = {
  // 🧹 Semaine poussière (non hebdo)
  // (mêmes lieux/slots que hebdo par défaut — tu peux adapter)
  'monday': [
    //----Après-midi----
    {'place': 'SAVS', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
    
  ],
  'tuesday': [
    //----Matin----
    {'place': 'Foyer de vie', 'timeSlot': 'morning'},
    {'place': 'Médico social', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
  ],
  'wednesday': [
    //----Matin----
    {'place': 'Bureaux Administratif', 'timeSlot': 'morning'},
    {'place': 'Le T5', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Bureaux Administratif', 'timeSlot': 'afternoon'},
    {'place': 'Foyer de vie', 'timeSlot': 'afternoon'},
  ],
  'thursday': [
    //----Matin----
    {'place': 'Appart Bruno', 'timeSlot': 'morning'},
  ],
  
};

/// ----------------------------------------
/// 🔧 Génère les events d’UN JOUR selon le type
/// ----------------------------------------
/// [dayName] ∈ monday, tuesday, wednesday, thursday, friday
/// [dustWeek] == true  → non hebdo (isWeeklyTask=false, task='Poussières')
/// [dustWeek] == false → hebdo     (isWeeklyTask=true,  task='')
List<Map<String, dynamic>> generateDayTypeEvents({
  required String dayName,
  required DateTime dayDate,
  required int weekNumber,
  required bool dustWeek,
}) {
  final key = dayName.toLowerCase();
  if (!_daysOrder.contains(key)) return [];

  // 🔹 On récupère la source, si absente -> []
  final source = dustWeek
      ? (kDustType[key] ?? <Map<String, String>>[])
      : (kWeeklyType[key] ?? <Map<String, String>>[]);

  final bool isWeeklyTask = !dustWeek;
  final String task = dustWeek ? 'Poussières' : '';

  return source.map((item) {
    return {
      'day': Timestamp.fromDate(
        DateTime(dayDate.year, dayDate.month, dayDate.day),
      ),
      'timeSlot': item['timeSlot'],
      'place': item['place'],
      'subPlace': <String>[],
      'task': task,
      'workerIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'weekNumber': weekNumber,
      'isWeeklyTask': isWeeklyTask,
      'isReprogrammed': false,
    };
  }).toList();
}

/// --------------------------------------------------
/// 🧩 Génère les events de TOUTE LA SEMAINE (L→V)
/// --------------------------------------------------
List<Map<String, dynamic>> generateWeekTypeEvents({
  required DateTime mondayDate,
  required int weekNumber,
  required bool dustWeek,
}) {
  final List<Map<String, dynamic>> all = [];

  for (int i = 0; i < 5; i++) {
    final dayDate = mondayDate.add(Duration(days: i));
    final dayName = _daysOrder[i];
    all.addAll(
      generateDayTypeEvents(
        dayName: dayName,
        dayDate: dayDate,
        weekNumber: weekNumber,
        dustWeek: dustWeek,
      ),
    );
  }

  return all;
}
