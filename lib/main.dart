import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'core/services/token_service.dart';
import 'features/config/config_screen.dart';
import 'features/print_server/print_server_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await TokenService.load(); // le jeton existe avant que le serveur démarre
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
    // Notifications (Android 13+) : la notification « actif » garde le service en vie
    final notif = await FlutterForegroundTask.checkNotificationPermission();
    if (notif != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    // Batterie : sans exemption, certains fabricants tuent le service malgré tout
    if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      await FlutterForegroundTask.requestIgnoreBatteryOptimization();
    }
    if (await FlutterForegroundTask.isRunningService) return; // déjà actif
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
