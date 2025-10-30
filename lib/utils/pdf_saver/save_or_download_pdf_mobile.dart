import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> saveOrDownloadPdf(Uint8List pdfBytes, String fileName) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/scheduleWeeklyCategory/$fileName');
  if (!await file.parent.exists()) await file.parent.create(recursive: true);
  await file.writeAsBytes(pdfBytes);
  await OpenFilex.open(file.path);
}
