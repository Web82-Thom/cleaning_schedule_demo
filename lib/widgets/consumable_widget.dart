import 'package:flutter/material.dart';

class ConsumableWidget extends ChangeNotifier{
  List<String> products = [
    'prokliks brillant Rouge',
    'prokliks energy Bleu',
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
    'Caisse',
    'T5'
  ];

  // les transferts
  List<String> transfer= [
    'Foyer de vie',
    'Foyer d\'hébergement',
  ];

  List<String> villas= [
    '1',
    '2',
  ];
}