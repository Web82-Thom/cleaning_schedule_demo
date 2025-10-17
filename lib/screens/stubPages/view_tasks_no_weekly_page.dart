import 'package:cleaning_schedule/widgets/table_date_task_no_weekly_widget.dart';
import 'package:cleaning_schedule/widgets/tasks_widget.dart';
import 'package:flutter/material.dart';

class ViewTasksNoWeeklyPage extends StatelessWidget {
  const ViewTasksNoWeeklyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final tasksWidget = TasksWidget();

    return Scaffold(
      appBar: AppBar(title: const Text('Divers')),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 3, // 3 cartes par ligne
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          children: tasksWidget.tasksNoWeekly.map((task) {
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
          }).toList(),
        ),
      ),
    );
  }
}
