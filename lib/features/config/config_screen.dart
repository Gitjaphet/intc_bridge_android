import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/constants/app_constants.dart';
import '../../core/models/printer_config.dart';
import '../../core/services/config_service.dart';
import '../../core/services/token_service.dart';

/// ESC @ (init), centré, texte, avance papier, coupe — même ticket que le pont PC.
final List<int> _testTicket = [
  0x1B, 0x40, 0x1B, 0x61, 0x01,
  ...ascii.encode("INTC Bridge Android\nTest d'impression OK\n\n\n\n"),
  0x1D, 0x56, 0x42, 0x00,
];

class ConfigScreen extends StatefulWidget {
  const ConfigScreen({super.key});

  @override
  State<ConfigScreen> createState() => _ConfigScreenState();
}

class _ConfigScreenState extends State<ConfigScreen> {
  final ConfigService _configService = ConfigService();
  PrinterConfig _config = const PrinterConfig();
  List<BluetoothDevice> _devices = [];
  bool _isScanning = false;
  bool _isSaving = false;
  bool _isTesting = false;
  String _token = '';

  final TextEditingController _wifiIpController = TextEditingController();
  final TextEditingController _wifiPortController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _requestPermissionsAndLoad();
    TokenService.load().then((t) {
      if (mounted) setState(() => _token = t);
    });
  }

  Future<void> _requestPermissionsAndLoad() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final config = await _configService.load();
    setState(() {
      _config = config;
      _wifiIpController.text = config.wifiIp ?? '';
      _wifiPortController.text = config.wifiPort.toString();
    });
    if (config.connectionType == ConnectionType.bluetooth) {
      _scanDevices();
    }
  }

  Future<void> _scanDevices() async {
    setState(() => _isScanning = true);
    final devices = await FlutterBluetoothSerial.instance.getBondedDevices();
    setState(() {
      _devices = devices;
      _isScanning = false;
    });
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await _configService.save(_config);
    setState(() => _isSaving = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration sauvegardée !')),
      );
    }
  }

  /// Imprime via le vrai chemin (HTTP + jeton), exactement comme le fera Odoo.
  Future<void> _testPrint() async {
    setState(() => _isTesting = true);
    String message;
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final req = await client.postUrl(
          Uri.parse('http://127.0.0.1:${AppConstants.httpPort}/rawprint'));
      req.headers.set('X-Bridge-Token', _token);
      req.headers.contentType = ContentType.binary;
      req.add(_testTicket);
      final res = await req.close();
      final body = jsonDecode(await res.transform(utf8.decoder).join());
      message = res.statusCode == 200
          ? "Ticket envoyé. S'il est sorti, la configuration est bonne."
          : 'Erreur : ${body['message']}';
    } on SocketException {
      message = "Le service d'impression n'est pas démarré.";
    } catch (e) {
      message = 'Erreur : $e';
    } finally {
      client.close();
    }
    if (!mounted) return;
    setState(() => _isTesting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Icon(Icons.print, size: 72, color: Colors.blue[700]),
            ),
            const SizedBox(height: 32),

            const Text('1. Taille du papier',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PaperSizeButton(
                    label: 'Petite (58mm)',
                    selected: _config.paperSize == PrinterPaperSize.mm58,
                    onTap: () => setState(() => _config = PrinterConfig(
                          connectionType: _config.connectionType,
                          paperSize: PrinterPaperSize.mm58,
                          bluetoothAddress: _config.bluetoothAddress,
                          bluetoothName: _config.bluetoothName,
                          wifiIp: _config.wifiIp,
                          wifiPort: _config.wifiPort,
                        )),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PaperSizeButton(
                    label: 'Grande (80mm)',
                    selected: _config.paperSize == PrinterPaperSize.mm80,
                    onTap: () => setState(() => _config = PrinterConfig(
                          connectionType: _config.connectionType,
                          paperSize: PrinterPaperSize.mm80,
                          bluetoothAddress: _config.bluetoothAddress,
                          bluetoothName: _config.bluetoothName,
                          wifiIp: _config.wifiIp,
                          wifiPort: _config.wifiPort,
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            const Text('2. Type de connexion',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ConnectionButton(
                    label: 'Bluetooth',
                    selected: _config.connectionType == ConnectionType.bluetooth,
                    onTap: () {
                      setState(() => _config = PrinterConfig(
                            connectionType: ConnectionType.bluetooth,
                            paperSize: _config.paperSize,
                            bluetoothAddress: _config.bluetoothAddress,
                            bluetoothName: _config.bluetoothName,
                            wifiIp: _config.wifiIp,
                            wifiPort: _config.wifiPort,
                          ));
                      _scanDevices();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ConnectionButton(
                    label: 'Wi-Fi / Réseau',
                    selected: _config.connectionType == ConnectionType.wifi,
                    onTap: () => setState(() => _config = PrinterConfig(
                          connectionType: ConnectionType.wifi,
                          paperSize: _config.paperSize,
                          bluetoothAddress: _config.bluetoothAddress,
                          bluetoothName: _config.bluetoothName,
                          wifiIp: _config.wifiIp,
                          wifiPort: _config.wifiPort,
                        )),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            if (_config.connectionType == ConnectionType.bluetooth) ...[
              Row(
                children: [
                  const Text('Appareil Bluetooth',
                      style: TextStyle(fontSize: 14, color: Colors.grey)),
                  const Spacer(),
                  IconButton(
                    icon: _isScanning
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh, color: Colors.blue),
                    onPressed: _isScanning ? null : _scanDevices,
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _config.bluetoothAddress,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    hint: const Text('Sélectionner une imprimante'),
                    items: _devices.map((device) {
                      return DropdownMenuItem(
                        value: device.address,
                        child: Row(
                          children: [
                            const Icon(Icons.bluetooth, color: Colors.blue, size: 18),
                            const SizedBox(width: 8),
                            Text(device.name?.isNotEmpty ?? false
                                ? device.name!
                                : device.address),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (address) {
                      final device = _devices.firstWhere(
                          (d) => d.address == address);
                      setState(() => _config = PrinterConfig(
                            connectionType: _config.connectionType,
                            paperSize: _config.paperSize,
                            bluetoothAddress: address,
                            bluetoothName: device.name,
                            wifiIp: _config.wifiIp,
                            wifiPort: _config.wifiPort,
                          ));
                    },
                  ),
                ),
              ),
            ],

            if (_config.connectionType == ConnectionType.wifi) ...[
              TextField(
                controller: _wifiIpController,
                decoration: InputDecoration(
                  labelText: 'Adresse IP de l\'imprimante',
                  hintText: '192.168.1.100',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _config = PrinterConfig(
                  connectionType: _config.connectionType,
                  paperSize: _config.paperSize,
                  bluetoothAddress: _config.bluetoothAddress,
                  bluetoothName: _config.bluetoothName,
                  wifiIp: val,
                  wifiPort: _config.wifiPort,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _wifiPortController,
                decoration: InputDecoration(
                  labelText: 'Port (défaut: 9100)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                keyboardType: TextInputType.number,
                onChanged: (val) => _config = PrinterConfig(
                  connectionType: _config.connectionType,
                  paperSize: _config.paperSize,
                  bluetoothAddress: _config.bluetoothAddress,
                  bluetoothName: _config.bluetoothName,
                  wifiIp: _config.wifiIp,
                  wifiPort: int.tryParse(val) ?? 9100,
                ),
              ),
            ],

            const SizedBox(height: 32),
            const Text('3. Jeton pour Odoo',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text(
                'Odoo le demande une seule fois, à la première impression depuis ce téléphone.',
                style: TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.only(left: 16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(_token,
                        style: const TextStyle(fontFamily: 'monospace')),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.blue),
                    tooltip: 'Copier',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _token));
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Jeton copié')));
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('SAUVEGARDER',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isTesting ? null : _testPrint,
                icon: const Icon(Icons.receipt_long),
                label: Text(_isTesting ? 'ENVOI…' : 'IMPRIMER UN TICKET DE TEST'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaperSizeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _PaperSizeButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 16),
            if (selected) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _ConnectionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConnectionButton(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? Colors.blue : Colors.transparent,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (selected)
              const Icon(Icons.check, color: Colors.white, size: 16),
            if (selected) const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: selected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}
