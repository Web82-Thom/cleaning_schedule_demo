import 'dart:io';
import 'package:cleaning_schedule/controllers/pdf_controller.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class ListPdfPage extends StatefulWidget {
  const ListPdfPage({super.key});

  @override
  State<ListPdfPage> createState() => _ListPdfPageState();
}

class _ListPdfPageState extends State<ListPdfPage> {

  final PdfController pdfController = PdfController();
  List<FileSystemEntity> _files = [];
  bool _loading = true;
  String _title = 'PDFs';
  String _fileNamePrefix = '';
  String _elementName = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      _title = args['title'] ?? _title;
      _fileNamePrefix = args['fileNamePrefix'] ?? '';
      _elementName = args['elementName'] ?? '';
    }
    _loadFiles();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final dir = await getApplicationDocumentsDirectory();
      final allFiles = dir.listSync().where((f) => f.path.endsWith('.pdf'));

      final safePrefix = _fileNamePrefix.toLowerCase().replaceAll(' ', '_');
      final safeElement = _elementName.toLowerCase().replaceAll(' ', '_');

      _files = allFiles.where((f) {
        final name = f.path.split('/').last.toLowerCase();
        return name.startsWith('conso_${safePrefix}_$safeElement');
      }).toList();
    } catch (e) {
      debugPrint('Erreur listage PDFs: $e');
      _files = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('PDF : $_title - $_elementName'),
        backgroundColor: Colors.indigo,
      ),
      body: _loading ?
        const Center(child: CircularProgressIndicator()) :
        _files.isEmpty ? 
        const Center(child: Text('Aucun PDF pour le moment', style: TextStyle(color: Colors.grey))) :
        ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _files.length,
          itemBuilder: (context, i) {
            final f = _files[i];
            final name = f.path.split('/').last;
            return Card(
              child: ListTile(
                title: Text(name),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () async {
                    // On vérifie et on caste l'entité en File
                    if (f is File) {
                      await pdfController.deletePdfFromCategory(
                        context: context,
                        file: f,
                      );
                      _loadFiles(); // recharge la liste
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Erreur : élément non valide')),
                      );
                    }
                  },
                ),
                onTap: () => OpenFilex.open(f.path),
              ),
            );
          },
        ),
    );
  }
}
