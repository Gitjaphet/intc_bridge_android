import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import '../constants/app_constants.dart';
import '../models/print_job.dart';
import '../models/printer_config.dart';
import 'bluetooth_service.dart';
import 'wifi_printer_service.dart';
import 'escpos_service.dart';
import 'config_service.dart';
import 'token_service.dart';

class HttpServerService {
  HttpServer? _server;
  final BluetoothPrinterService _bluetooth = BluetoothPrinterService();
  final WifiPrinterService _wifi = WifiPrinterService();
  final EscPosService _escpos = EscPosService();
  final ConfigService _configService = ConfigService();

  Future<void> start() async {
    final router = Router();

    router.get('/health', (Request req) {
      return Response.ok(
          jsonEncode({'status': 'ok', 'app': AppConstants.appName}),
          headers: {'Content-Type': 'application/json'});
    });

    router.post('/print', (Request req) async {
      try {
        final body = await req.readAsString();
        final json = jsonDecode(body);
        final job = PrintJob.fromJson(json);
        final config = await _configService.load();

        final data = await _escpos.generateTicket(job, config);

        for (int i = 0; i < job.copies; i++) {
          if (config.connectionType == ConnectionType.bluetooth) {
            if (config.bluetoothAddress == null) {
              return Response.internalServerError(
                  body: jsonEncode({'status': 'error', 'message': 'Aucune imprimante configurée'}),
                  headers: {'Content-Type': 'application/json'});
            }
            // Reconnexion automatique si déconnecté
            await _bluetooth.printTo(config.bluetoothAddress!, data);
          } else {
            if (config.wifiIp == null) {
              return Response.internalServerError(
                  body: jsonEncode({'status': 'error', 'message': 'Aucune IP configurée'}),
                  headers: {'Content-Type': 'application/json'});
            }
            await _wifi.connect(config.wifiIp!, config.wifiPort);
            await _wifi.printData(data);
            await _wifi.disconnect();
          }
        }

        return Response.ok(
            jsonEncode({'status': 'printed', 'copies': job.copies}),
            headers: {'Content-Type': 'application/json'});
      } catch (e, st) {
        stderr.writeln('[RAWPRINT ERROR] $e\n$st');
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'Content-Type': 'application/json'});
      }
    });


    router.post('/rawprint', (Request req) async {
      try {
        final bodyBytes = await req.read().fold<List<int>>(
          [],
          (previous, element) => previous..addAll(element),
        );

        if (bodyBytes.isEmpty) {
          return Response(400,
              body: jsonEncode({'status': 'error', 'message': 'Corps vide'}),
              headers: {'Content-Type': 'application/json'});
        }

        final config = await _configService.load();

        if (config.connectionType == ConnectionType.bluetooth) {
          if (config.bluetoothAddress == null) {
            return Response.internalServerError(
                body: jsonEncode({'status': 'error', 'message': 'Aucune imprimante configurée'}),
                headers: {'Content-Type': 'application/json'});
          }
          await _bluetooth.printTo(config.bluetoothAddress!, Uint8List.fromList(bodyBytes));
        } else {
          if (config.wifiIp == null) {
            return Response.internalServerError(
                body: jsonEncode({'status': 'error', 'message': 'Aucune IP configurée'}),
                headers: {'Content-Type': 'application/json'});
          }
          await _wifi.connect(config.wifiIp!, config.wifiPort);
          await _wifi.printData(Uint8List.fromList(bodyBytes));
          await _wifi.disconnect();
        }

        return Response.ok(
            jsonEncode({'status': 'ok', 'bytes': bodyBytes.length}),
            headers: {'Content-Type': 'application/json'});
      } catch (e, st) {
        stderr.writeln('[RAWPRINT ERROR] $e\n$st');
        return Response.internalServerError(
            body: jsonEncode({'status': 'error', 'message': e.toString()}),
            headers: {'Content-Type': 'application/json'});
      }
    });

    final handler = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_authMiddleware())
        .addHandler(router.call);

    _server = await shelf_io.serve(
        handler, InternetAddress.loopbackIPv4, AppConstants.httpPort);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  bool get isRunning => _server != null;

  Middleware _corsMiddleware() {
    return (Handler handler) {
      return (Request req) async {
        if (req.method == 'OPTIONS') {
          return Response(204, headers: _corsHeaders());
        }
        final response = await handler(req);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  /// Toute impression (POST) doit présenter le jeton du pont.
  Middleware _authMiddleware() {
    return (Handler handler) {
      return (Request req) async {
        if (req.method == 'POST') {
          final expected = await TokenService.load();
          final sent = req.headers['x-bridge-token'] ?? '';
          if (!TokenService.matches(sent, expected)) {
            return Response(401,
                body: jsonEncode({'status': 'error', 'message': 'Jeton invalide'}),
                headers: {'Content-Type': 'application/json'});
          }
        }
        return handler(req);
      };
    };
  }

  Map<String, String> _corsHeaders() => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, X-Bridge-Token',
        'Access-Control-Allow-Private-Network': 'true',
      };
}
