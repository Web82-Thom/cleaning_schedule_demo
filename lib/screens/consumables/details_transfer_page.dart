import 'package:cleaning_schedule/screens/consumables/widgets/build_table_for_consumable_widget.dart';
import 'package:flutter/material.dart';

class DetailsTransferPage extends StatelessWidget {
  final String transfer;

  const DetailsTransferPage({super.key, required this.transfer});

  @override
  Widget build(BuildContext context) {
    return BuildTableForConsumableWidget(
      title: 'Transferts',
      fileNamePrefix: 'categoryTransfer',
      elementName: transfer,
      routePdfList: '/listPdfTransfer',
    );
  }
}
