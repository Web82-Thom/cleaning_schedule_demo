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
    {'place': 'Château', 'timeSlot': 'morning'},
    {'place': 'Mairie', 'timeSlot': 'morning'},
    {'place': 'Magasin Bricolage', 'timeSlot': 'morning'},
        //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
  ],
  'tuesday': [
    //----Matin----
    {'place': 'Château', 'timeSlot': 'morning'},
    {'place': 'Mairie', 'timeSlot': 'morning'},
    {'place': 'Magasin Bricolage', 'timeSlot': 'morning'},
        //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
    
  ],
  'wednesday': [
    //----Matin----
    {'place': 'Château', 'timeSlot': 'morning'},
    {'place': 'Mairie', 'timeSlot': 'morning'},
    {'place': 'Magasin Bricolage', 'timeSlot': 'morning'},
        //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
  ],
  'thursday': [
    //----Matin----
    {'place': 'Château', 'timeSlot': 'morning'},
    {'place': 'Mairie', 'timeSlot': 'morning'},
    {'place': 'Magasin Bricolage', 'timeSlot': 'morning'},
        //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
    
  ],
  'friday': [
    //----Matin----
    {'place': 'Château', 'timeSlot': 'morning'},
    {'place': 'Mairie', 'timeSlot': 'morning'},
    {'place': 'Magasin Bricolage', 'timeSlot': 'morning'},
        //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
    
    
  ],
};

final Map<String, List<Map<String, String>>> kDustType = {
  // 🧹 Semaine poussière (non hebdo)
  // (mêmes lieux/slots que hebdo par défaut — tu peux adapter)
  'monday': [
    //----Après-midi----
    {'place': 'Salle des fêtes', 'timeSlot': 'afternoon'},
    {'place': 'Château', 'timeSlot': 'afternoon'},
    
  ],
  'tuesday': [
    //----Matin----
    {'place': 'Manoir', 'timeSlot': 'morning'},
    {'place': 'maison jaune', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Château', 'timeSlot': 'afternoon'},
  ],
  'wednesday': [
    //----Matin----
    {'place': 'Bureaux Administratif', 'timeSlot': 'morning'},
    {'place': 'Magasin de bricolage', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Bureaux Administratif', 'timeSlot': 'afternoon'},
    {'place': 'maison jaune', 'timeSlot': 'afternoon'},
  ],
  'thursday': [
    //----Matin----
    {'place': 'Mairie', 'timeSlot': 'morning'},
    //----Après-midi----
    {'place': 'Manoir', 'timeSlot': 'afternoon'},
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
      'subPlace': '[]',
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
