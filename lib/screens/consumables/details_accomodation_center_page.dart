import 'package:flutter/material.dart';

class DetailsAccommodationCenterPage extends StatefulWidget {
  final String transfer; 
  DetailsAccommodationCenterPage({required this.transfer,super.key});

  @override
  State<DetailsAccommodationCenterPage> createState() => _DetailsAccomodationCenterPageState();
}

class _DetailsAccomodationCenterPageState extends State<DetailsAccommodationCenterPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}