import 'package:cleaning_schedule/controllers/pdf_controller.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BuildTableForConsumableWidget extends StatefulWidget {
  final String title;           // Ex: "Villa" / "Home Of Life"
  final String fileNamePrefix;  // Ex: "villa", "foyerDeVie"
  final String elementName;     // Ex: "T5", "Caisse"
  final String routePdfList;    // Route vers la liste PDF correspondante
  final String headerTitle;     // Change ne nom Lieu(x), Produits

  const BuildTableForConsumableWidget({
    super.key,
    required this.title,
    required this.fileNamePrefix,
    required this.elementName,
    required this.routePdfList,
    required this.headerTitle,
  });

  @override
  State<BuildTableForConsumableWidget> createState() => _BuildTableForConsumableWidgetState();
}

class _BuildTableForConsumableWidgetState extends State<BuildTableForConsumableWidget> {
  List<Map<String, dynamic>> _records = [];
  final PdfController pdfController = PdfController();
  

  @override
  void initState() {
    super.initState();
    _loadConsumablesFirestore();
  }

  /// 🔹 CHARGEMENT DES DONNÉES
  Future<void> _loadConsumablesFirestore() async {
  try {
    final doc = await FirebaseFirestore.instance
        .collection('consumables')
        .doc('${widget.fileNamePrefix}_${widget.elementName}')
        .get();

    if (doc.exists && doc.data()?['records'] != null) {
      final records = List<Map<String, dynamic>>.from(doc.data()!['records']);

      setState(() {
        _records = records.map((r) {
          final produitsList = (r['produits'] as List?)
              ?.map((p) => {
                    'nom': p['nom'] ?? '',
                    'quantite': p['quantite'] ?? '',
                  })
              .toList();

          return {
            'date': r['date'] ?? '',
            'produits': produitsList ?? [],
          };
        }).toList();
      });
    }
  } catch (e) {
    debugPrint('Erreur chargement consommables: $e');
  }
}

  /// 🔹 Sauvegarde améliorée avec détection du type d’action
  Future<void> _saveConsumablesToFirestore({
    String? action, // "ajout", "modif", "suppression"
  }) async {
    try {
      await FirebaseFirestore.instance
          .collection('consumables')
          .doc('${widget.fileNamePrefix}_${widget.elementName}')
          .set({
        'records': _records,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      String msg = 'Enregistré sur Firestore ✅';
      if (action == 'ajout') msg = 'Consommable ajouté ✅';
      if (action == 'modif') msg = 'Consommable modifié ✅';
      if (action == 'suppression') msg = 'Consommable supprimé ✅';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de sauvegarde : $e')),
        );
      }
    }
  }

  /// 🔹 DIALOGUE D'AJOUT / MODIF
  Future<void> _recordDialog({int? index}) async {
    final dateController = TextEditingController(
      text: index != null ? _records[index]['date'] : '',
    );

    // 🔹 On récupère la liste des produits existants (sinon on crée une liste vide)
    List<Map<String, String>> produits = [];
    if (index != null && _records[index]['produits'] != null) {
    produits = (_records[index]['produits'] as List)
        .map((p) => {
              'nom': (p['nom'] ?? '').toString(),
              'quantite': (p['quantite'] ?? '').toString(),
            })
        .toList();
  } else {
    produits = [{'nom': '', 'quantite': ''}];
  }


    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(index == null
                  ? 'Ajouter un consommable'
                  : 'Modifier le consommable'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9, // 🔹 plein écran
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔹 Date
                      TextField(
                        controller: dateController,
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Date'),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: ctx,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            dateController.text =
                                '${picked.day.toString().padLeft(2, '0')}/'
                                '${picked.month.toString().padLeft(2, '0')}/'
                                '${picked.year}';
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      // 🔹 Liste dynamique "Lieu" ou "Produit" + quantités
                      Column(
                        children: [
                          for (int i = 0; i < produits.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: TextField(
                                      decoration: InputDecoration(
                                        labelText: widget.title == 'Produit' ? 'Lieu' : 'Produit',
                                      ),
                                      onChanged: (v) => produits[i]['nom'] = v.trim(),
                                      controller:
                                          TextEditingController(text: produits[i]['nom']),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 2,
                                    child: TextField(
                                      decoration: const InputDecoration(labelText: 'Quantité'),
                                      keyboardType: TextInputType.number,
                                      onChanged: (v) => produits[i]['quantite'] = v.trim(),
                                      controller:
                                          TextEditingController(text: produits[i]['quantite']),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                    onPressed: () {
                                      setStateDialog(() {
                                        produits.removeAt(i);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () {
                                setStateDialog(() {
                                  produits.add({'nom': '', 'quantite': ''});
                                });
                              },
                              icon: const Icon(Icons.add, color: Colors.indigo),
                              label: Text(
                                widget.title == 'Produit'
                                    ? 'Ajouter un lieu'
                                    : 'Ajouter un produit',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                if (index != null)
                  TextButton(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (c2) => AlertDialog(
                          title: const Text('Supprimer cette fiche ?'),
                          content: const Text(
                              'Voulez-vous vraiment supprimer ce consommable ?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c2, false),
                              child: const Text('Annuler'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(c2, true),
                              child: const Text(
                                'Supprimer',
                                style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true && context.mounted) {
                        Navigator.pop(context);

                        setState(() {
                          _records.removeAt(index);
                        });

                        await _saveConsumablesToFirestore(action: 'suppression');

                        if (!mounted) return; // 🔒 Vérifie à nouveau après l'attente
                      }
                    },
                    child: const Text('Supprimer',
                        style: TextStyle(color: Colors.red)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Annuler'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() {
                      final data = {
                        'date': dateController.text,
                        'produits': produits,
                      };
                      if (index != null) {
                        _records[index] = data;
                      } else {
                        _records.add(data);
                      }
                    });
                    await _saveConsumablesToFirestore(
                      action: index != null ? 'modif' : 'ajout',
                    );
                  },
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} - ${widget.elementName}'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: () => _recordDialog(),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // 🔹 HEADER FIXE (PDF + Liste)
          Container(
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Générer PDF
              IconButton(
                icon: const Icon(Icons.picture_as_pdf, color: Colors.indigo, size: 30),
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Appui long pour créer un PDF.')),
                ),
                onLongPress: () => pdfController.generatePdfConsummables(context, widget.title, widget.elementName, widget.fileNamePrefix, _records),
              ),

              // Partager PDF
              IconButton(
                icon: const Icon(Icons.share, color: Colors.green, size: 28),
                onPressed: () async {
                  await pdfController.sharePdf(
                    context: context,
                    fileNamePrefix: widget.fileNamePrefix,
                    elementName: widget.elementName,
                    title: widget.title,
                  );
                },
              ),
              // Liste PDF
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  widget.routePdfList,
                  arguments: {
                    'title': widget.title,
                    'fileNamePrefix': widget.fileNamePrefix,
                    'elementName': widget.elementName,
                  },
                ),
                child: const Text('Liste PDF', style: TextStyle(color: Colors.indigo)),
              ),
            ],
          ),

          ),

          // 🔹 EN-TÊTE DU TABLEAU
          Container(
            color: Colors.indigo.shade100,
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text(widget.headerTitle, style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(flex: 1, child: Text('Qté', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          ),

          // 🔹 LISTE DÉFILANTE
          Expanded(
            child: _records.isEmpty
              ? const Center(child: Text('Aucun consommable'))
              : ListView.builder(
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    final record = _records[index];
                    final List<Map<String, dynamic>> produits =
                        (record['produits'] as List?)?.cast<Map<String, dynamic>>() ?? [];
                        final dateStr = record['date'];
String formattedDate = dateStr ?? '';

if (dateStr != null && dateStr.isNotEmpty) {
  try {
    // ✅ Si ta date vient déjà sous forme de string "24/10/2025", tu peux la parser :
    final parsed = DateFormat('dd/MM/yyyy').parse(dateStr);
    formattedDate = DateFormat('dd/MM/yy').format(parsed);
  } catch (e) {
    formattedDate = dateStr; // fallback au texte brut
  }
}

                    return InkWell(
                      onDoubleTap: () => _recordDialog(index: index),
                      onLongPress: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Supprimer cette fiche'),
                            content: const Text('Voulez-vous vraiment supprimer cette fiche ?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Annuler'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'Supprimer',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          setState(() {
                            _records.removeAt(index);
                          });
                          await _saveConsumablesToFirestore(action: 'suppression');
                        }
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 🔹 Date
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    formattedDate,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ),
                              ),

                              // 🔹 Produits
                              Expanded(
                                flex: 3,
                                child: produits.isEmpty
                                    ? const Text('—', style: TextStyle(color: Colors.grey))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: produits
                                            .map(
                                              (p) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 2),
                                                child: Text('• ${p['nom'] ?? ''}'),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),

                              // 🔹 Quantités
                              Expanded(
                                flex: 1,
                                child: produits.isEmpty
                                    ? const Text('—',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: Colors.grey))
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: produits
                                            .map(
                                              (p) => Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(vertical: 2),
                                                child: Text(
                                                  p['quantite']?.toString() ?? '',
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                      fontWeight: FontWeight.w600),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
