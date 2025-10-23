import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';

class BuildTableForConsumableWidget extends StatefulWidget {
  final String title;           // Ex: "Villa" / "Home Of Life" / "Transfer"
  final String fileNamePrefix;  // Ex: "villa", "foyer_de_vie"
  final String elementName;     // Ex: "T5", "Caisse"
  final String routePdfList;    // Route vers la liste PDF correspondante

  const BuildTableForConsumableWidget({
    super.key,
    required this.title,
    required this.fileNamePrefix,
    required this.elementName,
    required this.routePdfList,
  });

  @override
  State<BuildTableForConsumableWidget> createState() =>
      _BuildTableForConsumableWidgetState();
}

class _BuildTableForConsumableWidgetState
    extends State<BuildTableForConsumableWidget> {
  final List<Map<String, String>> _rows = [];

  void _addRow() {
    setState(() {
      _rows.add({'date': '', 'produit': '', 'quantite': ''});
    });
  }

  void _updateRow(int index, String key, String value) {
    setState(() {
      _rows[index][key] = value;
    });
  }

  void _removeRow(int index) {
    setState(() {
      _rows.removeAt(index);
    });
  }

  void _showFloatingMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _generatePdf(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exporter en PDF'),
        content:
            Text('Voulez-vous générer le PDF ${widget.title} ${widget.elementName}?'),
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

    if (confirmed != true) return;

    try {
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('${widget.title} - ${widget.elementName}',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.Table.fromTextArray(
                headers: ['Date', 'Produit', 'Quantité'],
                data: _rows
                    .map((row) => [
                          row['date'] ?? '',
                          row['produit'] ?? '',
                          row['quantite'] ?? ''
                        ])
                    .toList(),
              ),
            ],
          ),
        ),
      );

      final dir = await getApplicationDocumentsDirectory();

      final safePrefix = widget.fileNamePrefix.toLowerCase().replaceAll(' ', '_');
      final safeElement = widget.elementName.toLowerCase().replaceAll(' ', '_');
      final file = File('${dir.path}/conso_${safePrefix}_$safeElement.pdf');

      // 🔹 Écrase le fichier existant s'il existe
      if (await file.exists()) await file.delete();
      await file.writeAsBytes(await pdf.save());

      await OpenFilex.open(file.path);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'PDF généré et sauvegardé : ${file.path.split('/').last} ✅'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération PDF : $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                icon:
                    const Icon(Icons.picture_as_pdf, color: Colors.indigo, size: 30),
                onPressed: () =>
                    _showFloatingMessage(context, 'Appui long pour créer un PDF.'),
                onLongPress: () => _generatePdf(context),
              ),
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
          const Divider(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.indigo.shade50,
            child: const Row(
              children: [
                Expanded(
                    flex: 2,
                    child: Text('Date', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 3,
                    child: Text('Produit', style: TextStyle(fontWeight: FontWeight.bold))),
                Expanded(
                    flex: 2,
                    child: Text('Quantité', style: TextStyle(fontWeight: FontWeight.bold))),
                SizedBox(width: 40),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, index) {
                final row = _rows[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'JJ/MM',
                              border: InputBorder.none,
                            ),
                            onChanged: (v) => _updateRow(index, 'date', v),
                            initialValue: row['date'],
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            decoration: const InputDecoration(
                                hintText: 'Produit', 
                                border: InputBorder.none,
                              ),
                            onChanged: (v) => _updateRow(index, 'produit', v),
                            initialValue: row['produit'],
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            decoration: const InputDecoration(
                              hintText: 'Qté', 
                              border: InputBorder.none,
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _updateRow(index, 'quantite', v),
                            initialValue: row['quantite'],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _removeRow(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        onPressed: _addRow,
        child: const Icon(Icons.add),
      ),
    );
  }
}
