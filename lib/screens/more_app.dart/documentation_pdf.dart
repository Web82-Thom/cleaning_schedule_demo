import 'package:cleaning_schedule_demo/models/doc_model.dart';
import 'package:cleaning_schedule_demo/screens/PDF/pdf_viewer_page.dart';
import 'package:flutter/material.dart';

class DocumentationsPdfPage extends StatelessWidget {
  const DocumentationsPdfPage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<DocModel> docs = [
      DocModel(
        id: "guide_general",
        title: "Guide général",
        subtitle: "Présentation, navigation et utilisation globale.",
        icon: Icons.menu_book_outlined,
        color: Colors.indigo,
        assetPath: "assets/documentations/guide_general.pdf",
      ),
      DocModel(
        id: "planning",
        title: "Planning & événements",
        subtitle: "Créer, gérer et comprendre le planning.",
        icon: Icons.calendar_month_outlined,
        color: Colors.blue,
        assetPath: "assets/documentations/guide_planning.pdf",
      ),
      DocModel(
        id: "rdvs",
        title: "RDV & suivi",
        subtitle: "Gestion du calendrier RDV et moniteurs.",
        icon: Icons.event_available_outlined,
        color: Colors.teal,
        assetPath: "assets/documentations/guide_rdvs.pdf",
      ),
      DocModel(
        id: "divers",
        title: "Tâches diverses",
        subtitle: "Tâches non hebdomadaires & rapports.",
        icon: Icons.category_outlined,
        color: Colors.deepPurple,
        assetPath: "assets/documentations/guide_divers.pdf",
      ),
      DocModel(
        id: "consommables",
        title: "Consommables",
        subtitle: "Gestion des consommations & relevés.",
        icon: Icons.local_drink_outlined,
        color: Colors.orange,
        assetPath: "assets/documentations/guide_consumables.pdf",
      ),
      DocModel(
        id: "guide_complet",
        title: "Guide complet",
        subtitle: "Guide complet 'cleaning schedule'.",
        icon: Icons.local_drink_outlined,
        color: Colors.orange,
        assetPath: "assets/documentations/guide_complet_cleaning_schedule_demo.pdf",
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text(
          "Documentations PDF",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final doc = docs[index];
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                radius: 22,
                backgroundColor: doc.color.withOpacity(0.15),
                child: Icon(doc.icon, color: doc.color),
              ),
              title: Text(
                doc.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                doc.subtitle,
                style: const TextStyle(fontSize: 13),
              ),
              trailing: const Icon(Icons.picture_as_pdf, color: Colors.red),
             onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => PdfViewerPage(
        assetPath: doc.assetPath,
        title: doc.title,
      ),
    ),
  );
},

            ),
          );
        },
      ),
    );
  }
}
