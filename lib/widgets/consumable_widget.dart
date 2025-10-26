import 'package:flutter/material.dart';

class ConsumableWidget extends ChangeNotifier{
  List<String> products = [
    'FV Lave vaiselle prokliks brillant Rouge',
    'FV Lave vaiselle prokliks energy Bleu',
    'Détergent désinfectant Rose \'LE VRAI\'',
    'Décapant',
    'Dosettes',
    'FH Lave +', 
    'FH Rince +',
  ];

  List<String> cars = [
    'Berlingo',
    'Trafic',
  ];

  // foyer de vie
  List<String> homeOfLife= [
    'Caisse',
    'T5'
  ];

  // les transferts
  List<String> transfer= [
    'Foyer de vie',
    'Foyer d\'hébergement',
  ];

  List<String> villas= [
    'Pousiniès',
    'T4',
    'Appartement Bruno',
    'Appartement Kathleen',
    'Appartement Nicolas',
    'Gamot',
    'Amsterdam',
  ];

  List<String> otherPlaces= [
    'Salle externe',
  ];
}