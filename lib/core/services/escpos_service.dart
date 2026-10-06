import 'dart:typed_data';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../models/printer_config.dart';
import '../models/print_job.dart';

class EscPosService {
  Future<Uint8List> generateTicket(PrintJob job, PrinterConfig config) async {
    final profile = await CapabilityProfile.load();
    final paperSize = config.paperSize == PrinterPaperSize.mm58
        ? PaperSize.mm58
        : PaperSize.mm80;

    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    bytes += generator.setGlobalCodeTable('CP1252');

    final lines = job.content.split('\n');
    for (final line in lines) {
      if (line.trim().isEmpty) {
        bytes += generator.emptyLines(1);
      } else {
        bytes += generator.text(line);
      }
    }

    bytes += generator.cut();

    return Uint8List.fromList(bytes);
  }
}
