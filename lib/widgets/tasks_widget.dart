import 'package:flutter/material.dart';

class TasksWidget extends ChangeNotifier{
  
  List<String> tasksWeekly = [
    'Nettoyage matériel',
    'Frigo',
    'Auto-laveuse',
    'Gaze',
    'Désinfection',
    'Décapage cuisine',
    'Conteneur',
    'Draps',
  ];
  List<String> tasksNoWeekly = [
    'Vitres', 
    'Lessivage portes',
    'Poussières',
    'Faïences',
    'Remise en Etat',
    'Décapage',
    'Toiles d\'araignée',
    ];
}
