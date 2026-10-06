import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

class BluetoothPrinterService {
  BluetoothConnection? _connection;

  Future<void> connect(String address) async {
    _connection = await BluetoothConnection.toAddress(address);
  }

  Future<void> printData(Uint8List data) async {
    if (_connection == null || !_connection!.isConnected) {
      throw Exception('Imprimante Bluetooth non connectée');
    }
    const chunkSize = 512;
    for (int i = 0; i < data.length; i += chunkSize) {
      final end = (i + chunkSize > data.length) ? data.length : i + chunkSize;
      _connection!.output.add(data.sublist(i, end));
      await _connection!.output.allSent;
    }
  }

  void disconnect() {
    _connection?.dispose();
    _connection = null;
  }

  bool get isConnected => _connection?.isConnected ?? false;
}
