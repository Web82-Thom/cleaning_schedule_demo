import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TableDateTaskNoWeeklyWidget extends StatefulWidget {
  final String taskName;

  const TableDateTaskNoWeeklyWidget({
    super.key,
    required this.taskName,
  });

  @override
  State<TableDateTaskNoWeeklyWidget> createState() =>
      _TableDateTaskNoWeeklyWidgetState();
}

class _TableDateTaskNoWeeklyWidgetState
    extends State<TableDateTaskNoWeeklyWidget> {
  final CollectionReference monitoringRef =
      FirebaseFirestore.instance.collection('noWeeklyTasksMonitoring');

  bool _loading = true;
  List<Map<String, dynamic>> _pastEvents = [];

  @override
  void initState() {
    super.initState();
    _loadPastNoWeeklyForTask();
  }

  /// 🔹 Chargement des événements passés non hebdomadaires
  Future<void> _loadPastNoWeeklyForTask() async {
    try {
      final snap = await monitoringRef
          .where('task', isEqualTo: widget.taskName)
          .get();

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final list = snap.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final ts = data['day'] as Timestamp?;
        final date = ts?.toDate();

        return {
          'id': doc.id, // ✅ ID Firestore conservé
          'task': (data['task'] ?? '').toString(),
          'place': (data['place'] ?? '').toString(),
          'subPlace': (data['subPlace'] ?? '').toString(),
          'isWeeklyTask': (data['isWeeklyTask'] ?? false) as bool,
          'comment': (data['comment'] ?? '').toString(),
          'day': date,
        };
      }).where((e) {
        final date = e['day'] as DateTime?;
        if (date == null) return false;
        final d0 = DateTime(date.year, date.month, date.day);
        return (e['isWeeklyTask'] == false) && d0.isBefore(today);
      }).toList();

      // Tri du plus recent au plus ancien
      list.sort((a, b) =>
          (b['day'] as DateTime).compareTo(a['day'] as DateTime));

      setState(() {
        _pastEvents = list;
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement noWeeklyTasksMonitoring: $e');
      setState(() => _loading = false);
    }
  }

  /// 🔹 Boîte de dialogue pour ajouter / modifier un commentaire
  Future<void> _addCommentDialogToEvent(String eventId, String initialComment) async {
    final TextEditingController _commentController = TextEditingController(text: initialComment);

    await showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Ajouter un commentaire'),
          content: TextField(
            controller: _commentController,
            maxLines: 4,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Entrez votre commentaire ici',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              style:
                  ElevatedButton.styleFrom(backgroundColor: Colors.indigo),
              onPressed: () async {
                final comment = _commentController.text.trim();
                if (comment.isNotEmpty) {
                  await _addComment(eventId, comment);
                  await _loadPastNoWeeklyForTask(); // ✅ recharge les données après ajout
                }
                Navigator.pop(ctx);
              },
              child: const Text('Ok',style: TextStyle(color: Colors.white),),
            ),
            if(_commentController.text.isNotEmpty)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: (){
                  print('deleteComent $eventId');
                  _deleteCommentDialog(eventId);
                },
                child: Text('Supprimer le Commentaire', style: TextStyle(color: Colors.white),),)
          ],
        );
      },
    );
  }

  /// 🔹 Ajout / mise à jour du commentaire dans Firestore
  Future<void> _addComment(String eventId, String comment) async {
    try {
      await monitoringRef.doc(eventId).set(
        {'comment': comment},
        SetOptions(merge: true), // pour ne pas écraser les autres champs
      );
      debugPrint('Commentaire ajouté à l’événement $eventId');
    } catch (e) {
      debugPrint('Erreur Firestore lors de l’ajout du commentaire : $e');
    }
  }

  Future<void> _deleteCommentDialog(String eventId) async {
    try {
      await monitoringRef.doc(eventId).set(
        {'comment': FieldValue.delete()},
        SetOptions(merge: true), // pour ne pas écraser les autres champs
      );
      
      await _loadPastNoWeeklyForTask();
      
      Navigator.pop(context, true);
      setState(() {
        
      });
      debugPrint('Commentaire supprimé de l’événement $eventId');
    } catch (e) {
      debugPrint('Erreur Firestore lors de la suppression du commentaire : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Suivi — ${widget.taskName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: _loading 
      ? const Center(child: CircularProgressIndicator())
      : _pastEvents.isEmpty
      ? const Center(
          child: Text(
            'Aucun historique pour cette tâche.',
            style: TextStyle(fontSize: 16),
          ),
        )
      : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _pastEvents.length,
        itemBuilder: (context, index) {
          final event = _pastEvents[index];
          final date = event['day'] as DateTime?;

          final formattedDate = date != null
          ? DateFormat('dd MMM yyyy', 'fr_FR').format(date)
          : '—';

          // ✅ Condition sur le commentaire vide
          final comment = (event['comment'] ?? '').trim();
          final hasComment = comment.isNotEmpty;
              

          return Card(
            margin: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 8,
            ),
            elevation: 1,
            child: ListTile(
              title: Text(
                '${event['place']} - ${event['subPlace']}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.message),
                color: Colors.green,
                onPressed: () {
                  _addCommentDialogToEvent(
                    event['id'], // ✅ vrai ID Firestore
                    event['comment'],
                  );
                },
              ),
              subtitle: Text(
                hasComment
                ? '$formattedDate\nCommentaire: $comment'
                : formattedDate,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        },
      ),
    );
  }
}
