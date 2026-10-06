import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'features/config/config_screen.dart';
import 'features/print_server/print_server_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  PrintServerService.initForegroundTask();
  runApp(const IntcBridgeApp());
}

class IntcBridgeApp extends StatefulWidget {
  const IntcBridgeApp({super.key});

  @override
  State<IntcBridgeApp> createState() => _IntcBridgeAppState();
}

class _IntcBridgeAppState extends State<IntcBridgeApp> {
  @override
  void initState() {
    super.initState();
    _startService();
  }

  Future<void> _startService() async {
    await PrintServerService.start();
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: MaterialApp(
        title: 'INTC Bridge',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const ConfigScreen(),
      ),
    );
  }
}
