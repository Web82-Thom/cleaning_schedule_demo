import 'package:flutter/material.dart';

class TasksWidget extends ChangeNotifier{
  
  List<String> tasksWeekly = [
    'Nettoyage bureaux',
    'Entretien jardin',
    'Lavage vitres',
  ];
  List<String> tasksNoWeekly = [
    'Grand ménage', 
    'Nettoyage après événement',
    ];
}
