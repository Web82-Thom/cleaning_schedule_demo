import 'package:cleaning_schedule/controllers/pdf_controller.dart';
import 'package:cleaning_schedule/widgets/table_date_task_no_weekly_widget.dart';
import 'package:cleaning_schedule/widgets/tasks_widget.dart';
import 'package:flutter/material.dart';

class ViewTasksNoWeeklyPage extends StatelessWidget {
  const ViewTasksNoWeeklyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasksWidget = TasksWidget();
    final PdfController pdfController = PdfController();

    return Scaffold(
      appBar: AppBar(title: const Text('Liste des prestations effectuées', style:TextStyle(fontSize: 14, fontWeight: FontWeight.bold),)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // 🔹 Barre d’actions au-dessus
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                    tooltip: 'Exporter en PDF',
                    onPressed: (){},
                    onLongPress: () {
                      pdfController.generateFullReport(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.indigo, size: 30),
                    tooltip: 'Partager',
                    onPressed: () {
                      pdfController.shareReportPdf(context: context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.remove_red_eye, color: Colors.green, size: 30),
                    tooltip: 'Voir',
                    onPressed: () {
                      pdfController.openExistingPdf(context: context, fileName: 'rapport_prestations_non_hebdo.pdf');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 🔹 Grille des tâches
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: List.generate(tasksWidget.tasksNoWeekly.length, (index) {
                    final task = tasksWidget.tasksNoWeekly[index];

                    final colors = [
                      Colors.red.shade100,
                      Colors.blue.shade100,
                      Colors.green.shade100,
                      Colors.orange.shade100,
                      Colors.purple.shade100,
                      Colors.teal.shade100,
                      Colors.yellow.shade100,
                    ];
                    final bgColor = colors[index % colors.length];

                    return InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TableDateTaskNoWeeklyWidget(taskName: task),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        color: bgColor,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              task,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
