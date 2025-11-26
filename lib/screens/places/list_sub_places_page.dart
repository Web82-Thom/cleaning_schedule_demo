import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ListSubPlacesPage extends StatelessWidget {
  final String placeId;
  final String name;
  final bool containsRooms;

  const ListSubPlacesPage({
    super.key,
    required this.placeId,
    required this.name,
    required this.containsRooms,
  });

  @override
  Widget build(BuildContext context) {
    final roomsRef = FirebaseFirestore.instance
        .collection('places')
        .doc(placeId)
        .collection('rooms');

    final placeRef = FirebaseFirestore.instance
        .collection('places')
        .doc(placeId);

    return SafeArea(
      child: Scaffold(
        appBar: AppBar(title: Text(name), backgroundColor: Colors.indigo,
          foregroundColor: Colors.white ,),
      
        body: Padding(
          padding: const EdgeInsets.only(right: 12.0, left: 12, top:5, bottom: 80),
          child: StreamBuilder<QuerySnapshot>(
            stream: roomsRef.orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
      
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                // ✅ Si aucune pièce, on repasse automatiquement containsRooms à false
                placeRef.update({'containsRooms': false});
                return const Center(
                  child: Text(
                    'Aucune pièce trouvée.\nAppuyez sur + pour en ajouter une.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }
      
              final rooms = snapshot.data!.docs;
      
              // ✅ Si au moins une pièce, s’assurer que containsRooms = true
              placeRef.update({'containsRooms': true});
      
              return ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, index) {
                  final data = rooms[index].data() as Map<String, dynamic>;
                  final roomName = data['name'] ?? 'Sans nom';
                  final id = rooms[index].id;
      
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.meeting_room, color: Colors.blue, size: 14,),
                      title: Text(
                        roomName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                          size: 16,
                        ),
                        onPressed: () {
                          deleteRoomWithConfirmation(
                            context,
                            roomsRef,
                            id,
                            roomName,
                            placeRef,
                          );
                        },
                      ),
                    ),
                  );
                },
              );
              
            },
            
          ),
        ),
      
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: Colors.black, width: 1), // bordure noire
            borderRadius: BorderRadius.circular(8), // coins arrondis
          ),
          onPressed: () => _showAddRoomDialog(context, roomsRef, placeRef),
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une pièce'),
        ),
      ),
    );
  }

  /// ✅ Ajouter une pièce et mettre à jour containsRooms = true
  void _showAddRoomDialog(
    BuildContext context,
    CollectionReference roomsRef,
    DocumentReference placeRef,
  ) {
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Nouvelle pièce'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(hintText: 'Nom de la pièce'),
          ),
          actions: [
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.pop(context),
            ),
            ElevatedButton(
              child: const Text('Ajouter'),
              onPressed: () async {
                final name = nameController.text.trim();
                if (name.isEmpty) return;

                // 🔹 Ajout de la pièce
                await roomsRef.add({'name': name});

                // 🔹 Met à jour le lieu
                await placeRef.update({'containsRooms': true});

                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  /// ✅ Supprimer une pièce + vérifier si c’était la dernière
  Future<void> deleteRoomWithConfirmation(
    BuildContext context,
    CollectionReference roomsRef,
    String roomId,
    String roomName,
    DocumentReference placeRef,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Supprimer la pièce',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Voulez-vous vraiment supprimer la pièce "$roomName" ?',
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Supprimer'),
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
        );
      },
    ).then((value) => value ?? false);

    if (!confirm) return;

    try {
      await roomsRef.doc(roomId).delete();

      // 🔹 Vérifie s’il reste encore des pièces
      final remaining = await roomsRef.get();
      if (remaining.docs.isEmpty) {
        await placeRef.update({'containsRooms': false});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pièce supprimée avec succès'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
