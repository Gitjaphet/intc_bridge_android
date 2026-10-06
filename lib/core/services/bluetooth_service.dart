import 'dart:typed_data';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';

/// Connexion Bluetooth ouverte à chaque impression puis refermée (comme le pont PC) :
/// pas de connexion « fantôme » si l'imprimante est éteinte, et l'imprimante
/// reste libre pour un autre appareil entre deux impressions.
class BluetoothPrinterService {
  Future<void> _queue = Future.value();

  /// Met l'impression en file : deux impressions simultanées passent l'une après l'autre.
  Future<void> printTo(String address, Uint8List data) {
    final job = _queue.then((_) => _send(address, data));
    _queue = job.catchError((_) {}); // une impression ratée ne bloque pas les suivantes
    return job;
  }

  Future<void> _send(String address, Uint8List data) async {
    final connection = await BluetoothConnection.toAddress(address).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception(
          'Imprimante injoignable : éteinte, hors de portée ou utilisée par un autre appareil.'),
    );
    try {
      const chunkSize = 512;
      for (var i = 0; i < data.length; i += chunkSize) {
        final end = i + chunkSize > data.length ? data.length : i + chunkSize;
        connection.output.add(data.sublist(i, end));
        await connection.output.allSent;
      }
      await Future.delayed(const Duration(seconds: 1)); // laisse partir les derniers octets
    } finally {
      await connection.finish();
    }
  }
}
