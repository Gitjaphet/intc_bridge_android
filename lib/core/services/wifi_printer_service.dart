import 'dart:io';
import 'dart:typed_data';

class WifiPrinterService {
  Socket? _socket;

  Future<void> connect(String ip, int port) async {
    _socket = await Socket.connect(ip, port,
        timeout: const Duration(seconds: 5));
  }

  Future<void> printData(Uint8List data) async {
    if (_socket == null) {
      throw Exception('Imprimante WiFi non connectée');
    }
    _socket!.add(data);
    await _socket!.flush();
  }

  Future<void> disconnect() async {
    await _socket?.close();
    _socket = null;
  }

  bool get isConnected => _socket != null;
}
