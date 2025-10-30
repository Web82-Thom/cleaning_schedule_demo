import 'package:flutter/material.dart';

class ConsumableWidget extends ChangeNotifier{
  List<String> products = [
    'Lave vaiselle prokliks brillant Rouge',
    'Lave vaiselle prokliks energy Bleu',
    'Détergent désinfectant Rose \'LE VRAI\'',
    'Décapant',
    'Dosettes',
    'Lave +', 
    'Rince +',
  ];

  List<String> cars = [
    'Berlingo',
    'Trafic',
  ];

  // foyer de vie
  List<String> homeOfLife= [
    'Caisses',
    'Palettes'
  ];

  // les transferts
  List<String> transfer= [
    'Mairie',
    'Château',
  ];

  List<String> villas= [
    'Appartement T1',
    'Appartement T2',
    'Appartement T3',
    'Appartement T4',
    'Maison Jaune',
    'Manoir',
  ];

  List<String> otherPlaces= [
    'Salle des fêtes',
  ];
}