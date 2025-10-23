import 'package:flutter/material.dart';

class DetailsVillasPage extends StatefulWidget {
  final String villa;
   DetailsVillasPage({required this.villa,key});

  @override
  State<DetailsVillasPage> createState() => _DetailsVillasPageState();
}

class _DetailsVillasPageState extends State<DetailsVillasPage>
    with SingleTickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}