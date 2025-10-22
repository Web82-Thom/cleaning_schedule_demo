import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ToDoListPage extends StatefulWidget {
  const ToDoListPage({super.key});

  @override
  State<ToDoListPage> createState() => _ToDoListPageState();
}

class _ToDoListPageState extends State<ToDoListPage> {
  final List<Map<String, dynamic>> _tasks = [];

  void _addNewTask() {
    final today = DateFormat('dd/MM/yyyy').format(DateTime.now());
    setState(() {
      _tasks.add({
        'date': today,
        'note': '',
        'checked': false,
      });
    });
  }

  void _toggleCheck(int index) {
    setState(() {
      _tasks[index]['checked'] = !_tasks[index]['checked'];
    });
  }

  void _updateNote(int index, String value) {
    setState(() {
      _tasks[index]['note'] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To Do List'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addNewTask,
        tooltip: 'Ajouter une tâche',
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // 🔹 En-têtes du tableau
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              color: Colors.purple.shade100,
              child: const Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Center(
                      child: Text(
                        'Note',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Text(
                        'Check',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),

            // 🔹 Liste des tâches
            Expanded(
              child: _tasks.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucune tâche pour le moment",
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _tasks.length,
                      itemBuilder: (context, index) {
                        final task = _tasks[index];
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              // 📅 Date
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Text(task['date']),
                                ),
                              ),
                              // 📝 Note
                              Expanded(
                                flex: 5,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: TextField(
                                    decoration: const InputDecoration(
                                      border: InputBorder.none,
                                      hintText: "Écrire une note...",
                                    ),
                                    onChanged: (value) =>
                                        _updateNote(index, value),
                                    controller: TextEditingController(
                                      text: task['note'],
                                    ),
                                  ),
                                ),
                              ),
                              // ✅ Check
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: Checkbox(
                                    value: task['checked'],
                                    onChanged: (_) => _toggleCheck(index),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
