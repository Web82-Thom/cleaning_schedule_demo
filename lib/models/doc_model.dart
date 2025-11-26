import 'package:flutter/material.dart';

class DocModel {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String assetPath;

  DocModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.assetPath,
  });
}
