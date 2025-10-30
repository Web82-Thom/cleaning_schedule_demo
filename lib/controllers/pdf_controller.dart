import 'dart:io' show File, Directory;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../utils/pdf_saver/save_or_download_pdf.dart'; // 👈 remplace dart:html

class PdfController extends ChangeNotifier {
  /// ______________________________________
  ///|--------Function generaliser----------|
  ///|______________________________________|
  /// 🔹 Génère un PDF regroupant toutes les prestations non hebdomadaires
  Future<void> generateFullReport(context) async {
    try {
      final pdf = pw.Document();
      final now = DateTime.now();
      final formattedDate =
          DateFormat('dd MMM yyyy', 'fr_FR').format(now);

      // 🔹 Titre principal
      final titleStyle = pw.TextStyle(
        fontSize: 20,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.indigo,
      );

      // 🔹 Charger logo (facultatif)
      final logoData =
          await rootBundle.load('assets/icon/app_icon.png');
      final logo = pw.MemoryImage(logoData.buffer.asUint8List());

      // 🔹 PAGE DE GARDE
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.Image(logo, width: 100, height: 100),
                pw.SizedBox(height: 20),
                pw.Text('Rapport complet des prestations effectuées',
                    style: titleStyle),
                pw.SizedBox(height: 10),
                pw.Text(
                  'Généré le $formattedDate',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );

      // 🔹 Récupération des données Firestore
      final snap = await FirebaseFirestore.instance
          .collection('noWeeklyTasksMonitoring')
          .get();

      if (snap.docs.isEmpty) {
        pdf.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Text(
                'Aucune prestation trouvée.',
                style: const pw.TextStyle(fontSize: 16),
              ),
            ),
          ),
        );
      } else {
        // 🔹 Groupement par tâche
        final Map<String, List<Map<String, dynamic>>> grouped = {};

        for (final doc in snap.docs) {
          final data = doc.data();
          final task = (data['task'] ?? 'Autre').toString();
          final place = (data['place'] ?? '—').toString();
          final ts = data['day'] as Timestamp?;
          final date = ts?.toDate();

          grouped.putIfAbsent(task, () => []);
          grouped[task]!.add({
            'place': place,
            'day': date != null
                ? DateFormat('dd MMM yyyy', 'fr_FR').format(date)
                : '—',
          });
        }

        // 🔹 Tri alphabétique des tâches
        final sortedKeys = grouped.keys.toList()..sort();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            header: (context) => pw.Container(
              alignment: pw.Alignment.centerLeft,
              child: pw.Text('Liste des prestations effectuées',
                  style: pw.TextStyle(
                    color: PdfColors.indigo,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  )),
            ),
            footer: (context) => pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Page ${context.pageNumber}/${context.pagesCount}',
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
              ),
            ),
            build: (context) => [
              for (final task in sortedKeys) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  '• $task',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo900,
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Table.fromTextArray(
                  headers: ['Lieu', 'Date'],
                  headerStyle: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white,
                  ),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.indigo),
                  cellAlignment: pw.Alignment.centerLeft,
                  cellPadding:
                      const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                  data: grouped[task]!
                      .map((e) => [e['place'], e['day']])
                      .toList(),
                ),
                pw.Divider(),
              ],
            ],
          ),
        );
      }

      // 🔹 Sauvegarde du PDF
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/rapport_prestations_non_hebdo.pdf');
      await file.writeAsBytes(await pdf.save());

      // 🔹 Ouvrir le PDF
      await OpenFilex.open(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Rapport PDF généré avec succès'),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération PDF : $e'),
          ),
        );
      }
    }
  }
  
  /// 🔹 Partage le rapport PDF complet des tâches non hebdomadaires
  Future<void> shareReportPdf({
    required BuildContext context,
  }) async {
    try {
      // 📂 Répertoire local de stockage
      final dir = await getApplicationDocumentsDirectory();
      const fileName = 'rapport_prestations_non_hebdo.pdf';
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      // 🔎 Vérifie si le fichier existe
      if (await file.exists()) {
        final XFile xfile = XFile(filePath);

        final ShareParams params = ShareParams(
          files: [xfile],
          text:
              '📄 Rapport des prestations non hebdomadaires généré avec Cleaning Schedule.',
          subject: 'Rapport PDF — Prestations effectuées',
        );

        final result = await SharePlus.instance.share(params);

        // ✅ Confirmation visuelle
        if (result.status == ShareResultStatus.success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF partagé avec succès ✅')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun rapport trouvé, veuillez le générer d’abord.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }

  /// 🔹 Supprime un fichier PDF local s’il existe
  Future<void> deletePdf({
    required BuildContext context,
    required String fileName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF "$fileName" supprimé avec succès ✅'),
            ),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Aucun fichier à supprimer.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression : $e'),
          ),
        );
      }
    }
  }

  /// ______________________________________
  ///|--------Function generaliser----------|
  ///|______________________________________|
  /// Supprime un PDF avec confirmation
  Future<void> deletePdfFromCategory({
    required BuildContext context,
    required File file,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le PDF'),
        content: Text('Voulez-vous vraiment supprimer ${file.path.split('/').last} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      if (await file.exists()) {
        await file.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('PDF supprimé : ${file.path.split('/').last} ✅')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e')),
        );
      }
    }
  }
 
  ///------Partager un pdf---------
  Future<void> sharePdf({
  required BuildContext context,
  required String fileNamePrefix,
  required String elementName,
  required String title,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final safePrefix = fileNamePrefix.toLowerCase().replaceAll(' ', '_');
      final safeElement = elementName.toLowerCase().replaceAll(' ', '_');
      final filePath = '${dir.path}/conso_${safePrefix}_$safeElement.pdf';
      final file = File(filePath);

      if (await file.exists()) {
        final XFile xfile = XFile(filePath);
        final ShareParams params = ShareParams(
          files: [xfile],
          text: 'Consommation : $title - $elementName',
          subject: 'PDF consommation',
        );

        final result = await SharePlus.instance.share(params);

        // Tu peux vérifier `result.status` si besoin
        if (result.status == ShareResultStatus.success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF partagé avec succès ✅')),
          );
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucun PDF trouvé, créez-le d’abord.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du partage : $e')),
        );
      }
    }
  }
 
 /// 🔹 Ouvre un PDF existant dans le visualiseur natif
  Future<void> openExistingPdf({
    required BuildContext context,
    required String fileName,
  }) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filePath = '${dir.path}/$fileName';
      final file = File(filePath);

      if (await file.exists()) {
        await OpenFilex.open(file.path);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Aucun PDF trouvé : $fileName')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l’ouverture : $e')),
        );
      }
    }
  }

  ///___________________________________________________
  ///|------Génère le PDF du planning hebdomadaire------|
  ///|__________________________________________________|
  static Future<void> generateWeeklyPdf({
    required List<Map<String, dynamic>> events,
    required Map<String, String> workersMap,
    required int weekNumber,
  }) async {
    final pdf = pw.Document();

    final days = events.map((e) => e['day'] as DateTime).toSet().toList()..sort();

    Map<String, List<Map<String, dynamic>>> grouped = {};
    for (var e in events) {
      final key = '${DateFormat('yyyy-MM-dd').format(e['day'])}_${e['timeSlot']}';
      grouped.putIfAbsent(key, () => []).add(e);
    }

    const int maxEventsPerCell = 6;

    pw.Widget buildEventList(List<Map<String, dynamic>> list, int startIndex) {
      if (list.isEmpty) {
        return pw.Text('—',
            style: const pw.TextStyle(color: PdfColors.grey700, fontSize: 10));
      }
      final sublist = list.skip(startIndex).take(maxEventsPerCell).toList();

      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: sublist.map((e) {
          final workers = (e['workerIds'] as List)
              .map((id) => workersMap[id] ?? 'Inconnu')
              .join(', ');

          String subPlaceText = '';
          if (e['subPlace'] != null) {
            if (e['subPlace'] is List) {
              subPlaceText =
                  (e['subPlace'] as List).whereType<String>().join(', ');
              if (subPlaceText.isNotEmpty) subPlaceText = ' ($subPlaceText)';
            } else if (e['subPlace'] is String &&
                e['subPlace'].trim().isNotEmpty) {
              subPlaceText = ' (${e['subPlace']})';
            }
          }

          final taskText = (e['task'] != null && e['task'].toString().isNotEmpty)
              ? ' • ${e['task']}'
              : '';

          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                e['place'] ?? 'Lieu inconnu',
                style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue800,
                    fontSize: 11),
              ),
              if (subPlaceText.isNotEmpty)
                pw.Text(subPlaceText,
                    style: const pw.TextStyle(
                        color: PdfColors.indigo, fontSize: 10)),
              if (taskText.isNotEmpty)
                pw.Text(taskText,
                    style: const pw.TextStyle(
                        color: PdfColors.deepPurple, fontSize: 10)),
              pw.Text('Travailleurs : $workers',
                  style: const pw.TextStyle(
                      color: PdfColors.grey800, fontSize: 9)),
              pw.SizedBox(height: 4),
            ],
          );
        }).toList(),
      );
    }

    for (var slot in ['morning', 'afternoon']) {
      int maxChunks = 1;
      Map<String, int> dayChunks = {};

      for (var day in days) {
        final key = '${DateFormat('yyyy-MM-dd').format(day)}_$slot';
        final count = grouped[key]?.length ?? 0;
        final chunks = (count / maxEventsPerCell).ceil();
        dayChunks[key] = chunks;
        if (chunks > maxChunks) maxChunks = chunks;
      }

      for (int chunkIndex = 0; chunkIndex < maxChunks; chunkIndex++) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(16),
            build: (context) => [
              pw.Text(
                '${slot == 'morning' ? 'MATIN' : 'APRÈS-MIDI'} - Semaine $weekNumber',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: slot == 'morning'
                      ? PdfColors.orange800
                      : PdfColors.teal800,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                columnWidths: {
                  for (int i = 0; i < days.length; i++)
                    i: const pw.FlexColumnWidth()
                },
                children: [
                  pw.TableRow(
                    children: days.map((day) {
                      final label =
                          DateFormat('EEEE', 'fr_FR').format(day).toUpperCase();
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Center(
                            child: pw.Text(label,
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.green,
                                    fontSize: 12))),
                      );
                    }).toList(),
                  ),
                  pw.TableRow(
                    children: days.map((day) {
                      final key =
                          '${DateFormat('yyyy-MM-dd').format(day)}_$slot';
                      return pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: buildEventList(
                            grouped[key] ?? [], chunkIndex * maxEventsPerCell),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ],
          ),
        );
      }
    }

    final pdfBytes = await pdf.save();
    await saveOrDownloadPdf(pdfBytes, 'planning_week_$weekNumber.pdf');
  }
 
  ///---------Float message for created PDF---------
  void showFloatingMessage(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    // if (overlay == null) return;

    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 50,
        left: MediaQuery.of(context).size.width * 0.2,
        width: MediaQuery.of(context).size.width * 0.6,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    Future.delayed(const Duration(seconds: 2), () {
      overlayEntry.remove();
    });
  }

  /// ___________________________________________________ 
  ///|   ---------------PRODUCTS------------------------ |
  ///|___________________________________________________|
  /// Génère un PDF pour un produit
  Future<void> generateListProductByNamePdf(
    String productName, List<Map<String, dynamic>> records) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            children: [
              pw.Text(
                'Relevés pour $productName',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.TableHelper.fromTextArray(
                headers: ['Date', 'Lieu'],
                data: records.map((r) => [r['date'] ?? '', r['place'] ?? '']).toList(),
                cellAlignment: pw.Alignment.centerLeft, // optionnel, style des cellules
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                headerDecoration: pw.BoxDecoration(color: PdfColors.blue200),
                cellHeight: 25,
              ),
            ],
          );
        },
      ),
    );

    final pdfBytes = await pdf.save();
    await savePdfToProductsCategory(productName, pdfBytes);
  }

  /// Enregistre le PDF dans le dossier productsCategory
  Future<File> savePdfToProductsCategory(String productName, List<int> pdfBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final categoryDir = Directory('${dir.path}/productsCategory');
    if (!await categoryDir.exists()) await categoryDir.create(recursive: true);

    final file = File('${categoryDir.path}/$productName.pdf');
    await file.writeAsBytes(pdfBytes, flush: true);
    notifyListeners();
    return file;
  }

  /// Supprime un PDF dans le dossier productsCategory avec confirmation
  Future<void> deletePdfFromProductsCategory(BuildContext context, String productName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final categoryDir = Directory('${dir.path}/productsCategory');
      
      // Nettoyage du nom du fichier (évite le ".pdf.pdf")
      final cleanName = productName.endsWith('.pdf') 
          ? productName 
          : '$productName.pdf';

      final file = File('${categoryDir.path}/$cleanName');

      if (await file.exists()) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Confirmation'),
            content: Text('Supprimer le fichier "$cleanName" ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Annuler'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        );

        if (confirm == true) {
          await file.delete();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('✅ Fichier "$cleanName" supprimé')),
          );
          notifyListeners();
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ Le fichier "$cleanName" n’existe pas')),
        );
      }
    } catch (e) {
      debugPrint('Erreur lors de la suppression du PDF : $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression ❌')),
      );
    }
  }

  //____________________________________________________ 
  //|   ---------------CARS------------------------     |
  //|___________________________________________________|
  /// Génère un PDF clair et structuré pour un véhicule
  Future<void> generateListCarByNamePdf(
    String carName,
    List<Map<String, dynamic>> records,
  ) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(20),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              'Relevé kilométrique - $carName',
              style: pw.TextStyle(
                fontSize: 22,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
          ),
          pw.SizedBox(height: 20),

          pw.TableHelper.fromTextArray(
            border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey500),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue100),
            headerHeight: 25,
            cellHeight: 22,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerRight,
              2: pw.Alignment.centerRight,
            },
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 12,
              color: PdfColors.blue900,
            ),
            cellStyle: const pw.TextStyle(fontSize: 11),
            headers: ['Mois', 'Relevé km', 'Résultat km'],
            data: records.map((r) {
              return [
                r['month'] ?? '',
                (r['value'] != null && r['value'].toString().isNotEmpty)
                    ? r['value']
                    : '-',
                r['diff'] ?? '-',
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Généré le ${DateFormat("dd/MM/yyyy à HH:mm", "fr_FR").format(DateTime.now())}',
            style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    final pdfBytes = await pdf.save();

    // ✅ Différencier web et mobile
    if (kIsWeb) {
      await saveOrDownloadPdf(pdfBytes, 'Releve_km_${carName.replaceAll(' ', '_')}.pdf');
    } else {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/Releve_km_$carName.pdf');
      await file.writeAsBytes(pdfBytes);
      await OpenFilex.open(file.path);
    }
    debugPrint('✅ PDF généré pour $carName');
  }

  ///---------Send to firebase---------------
  Future<File> savePdfToCarsCategory(String carName, List<int> pdfBytes) async {
    final dir = await getApplicationDocumentsDirectory();
    final categoryDir = Directory('${dir.path}/carsCategory');

    // Crée le dossier s'il n'existe pas
    if (!await categoryDir.exists()) {
      await categoryDir.create(recursive: true);
    }

    final cleanName = carName.endsWith('.pdf') ? carName : '$carName.pdf';
    final file = File('${categoryDir.path}/$cleanName');
    await file.writeAsBytes(pdfBytes, flush: true);

    notifyListeners();
    return file;
  }

  ///---------Supprime un PDF dans le dossier carsCategory avec confirmation-------------
  Future<void> deletePdfFromCarsCategory(BuildContext context, String fileName) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final categoryDir = Directory('${dir.path}/carsCategory');
      final file = File('${categoryDir.path}/$fileName');

      if (!await file.exists()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Le fichier "$fileName" n\'existe pas.')),
        );
        return;
      }

      await file.delete();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF "$fileName" supprimé avec succès 🗑️')),
        );
      }

      notifyListeners();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression : $e')),
        );
      }
      debugPrint('Erreur suppression PDF carsCategory : $e');
    }
  }

  /// 🔹 GÉNÉRATION DU PDF DES CONSOMMABLES
  Future<void> generatePdfConsummables(
    BuildContext context,
    String title,
    String elementName,
    String fileNamePrefix,
    List<Map<String, dynamic>> records,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exporter en PDF'),
        content: Text('Voulez-vous générer le PDF ($title) ($elementName) ?'),
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
      final now = DateTime.now();
      final formattedDate =
          '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';

      // 🔹 Logo (optionnel si absent)
      pw.MemoryImage? logoImage;
      try {
        final logoData = await rootBundle.load('assets/icon/app_icon.png');
        logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
      } catch (_) {
        debugPrint('⚠️ Logo introuvable (assets/icon/app_icon.png)');
      }

      final bool isProduits = title.toLowerCase().contains('produit');

      // 🔹 PAGE DE GARDE
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 100, height: 100),
                pw.SizedBox(height: 24),
                pw.Text(
                  title,
                  style: pw.TextStyle(
                    fontSize: 28,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.indigo,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(elementName, style: const pw.TextStyle(fontSize: 18)),
                pw.SizedBox(height: 30),
                pw.Text(
                  'Rapport ${isProduits ? 'de consommation des produits' : 'des prestations'}',
                  style: pw.TextStyle(
                    fontSize: 20,
                    color: PdfColors.indigo800,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'Exporté le $formattedDate',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );

      // 🔹 PAGE DE CONTENU
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerLeft,
            margin: const pw.EdgeInsets.only(bottom: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '$title - $elementName',
                  style: pw.TextStyle(
                    color: PdfColors.indigo,
                    fontWeight: pw.FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                pw.Text(
                  formattedDate,
                  style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 10),
            child: pw.Text(
              'Page ${context.pageNumber} / ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            ),
          ),
          build: (pw.Context context) {
            final List<List<String>> rows = [];

            for (final record in records) {
              final date = record['date'] ?? '';
              final List<Map<String, dynamic>> produits =
                  (record['produits'] as List?)?.cast<Map<String, dynamic>>() ?? [];

              for (final produit in produits) {
                rows.add([
                  date,
                  produit['nom'] ?? '',
                  produit['quantite'] ?? '',
                ]);
              }
            }

            final headers = ['Date', isProduits ? 'Lieu(x)' : 'Produit', 'Quantité'];

            return [
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              ),
              pw.SizedBox(height: 20),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  'Généré automatiquement le $formattedDate',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ),
            ];
          },
        ),
      );

      final pdfBytes = await pdf.save();

      // ✅ Gestion Web vs Mobile/Desktop
      if (kIsWeb) {
        await saveOrDownloadPdf(
          pdfBytes,
          'conso_${fileNamePrefix.toLowerCase().replaceAll(' ', '_')}_${elementName.toLowerCase().replaceAll(' ', '_')}.pdf',
        );
      } else {
        final dir = await getApplicationDocumentsDirectory();
        final safePrefix = fileNamePrefix.toLowerCase().replaceAll(' ', '_');
        final safeElement = elementName.toLowerCase().replaceAll(' ', '_');
        final file = File('${dir.path}/conso_${safePrefix}_$safeElement.pdf');

        if (await file.exists()) await file.delete();
        await file.writeAsBytes(pdfBytes);

        await OpenFilex.open(file.path);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF généré : ${fileNamePrefix.toUpperCase()} ✅'),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur PDF : $e\n$stack');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la génération du PDF : $e')),
        );
      }
    }
  }
}
