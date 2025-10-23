import 'package:flutter/material.dart';

class DetailsTransferPage extends StatefulWidget {
  final String transfer; 
  DetailsTransferPage({required this.transfer,super.key});

  @override
  State<DetailsTransferPage> createState() => _DetailsAccomodationCenterPageState();
}

class _DetailsAccomodationCenterPageState extends State<DetailsTransferPage>
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