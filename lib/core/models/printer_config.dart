enum ConnectionType { bluetooth, wifi }
enum PrinterPaperSize { mm58, mm80 }

class PrinterConfig {
  final ConnectionType connectionType;
  final PrinterPaperSize paperSize;
  final String? bluetoothAddress;
  final String? bluetoothName;
  final String? wifiIp;
  final int wifiPort;

  const PrinterConfig({
    this.connectionType = ConnectionType.bluetooth,
    this.paperSize = PrinterPaperSize.mm80,
    this.bluetoothAddress,
    this.bluetoothName,
    this.wifiIp,
    this.wifiPort = 9100,
  });

  Map<String, dynamic> toJson() => {
    'connectionType': connectionType.name,
    'paperSize': paperSize.name,
    'bluetoothAddress': bluetoothAddress,
    'bluetoothName': bluetoothName,
    'wifiIp': wifiIp,
    'wifiPort': wifiPort,
  };

  factory PrinterConfig.fromJson(Map<String, dynamic> json) => PrinterConfig(
    connectionType: ConnectionType.values.byName(json['connectionType'] ?? 'bluetooth'),
    paperSize: PrinterPaperSize.values.byName(json['paperSize'] ?? 'mm80'),
    bluetoothAddress: json['bluetoothAddress'],
    bluetoothName: json['bluetoothName'],
    wifiIp: json['wifiIp'],
    wifiPort: json['wifiPort'] ?? 9100,
  );
}
