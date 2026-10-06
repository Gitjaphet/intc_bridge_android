import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/http_server_service.dart';

class PrintServerService {
  static final HttpServerService _httpServer = HttpServerService();

  static void initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: AppConstants.notificationChannelId,
        channelName: AppConstants.notificationChannelName,
        channelDescription: AppConstants.notificationText,
        onlyAlertOnce: true,
        playSound: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
      ),
    );
  }

  static Future<void> start() async {
    await FlutterForegroundTask.startService(
      serviceId: AppConstants.notificationId,
      notificationTitle: AppConstants.notificationTitle,
      notificationText: AppConstants.notificationText,
      callback: startHttpServer,
    );
  }

  static Future<void> stop() async {
    await FlutterForegroundTask.stopService();
    await _httpServer.stop();
  }

  static bool get isRunning => _httpServer.isRunning;
}

@pragma('vm:entry-point')
void startHttpServer() {
  FlutterForegroundTask.setTaskHandler(PrintTaskHandler());
}

class PrintTaskHandler extends TaskHandler {
  final HttpServerService _httpServer = HttpServerService();

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _httpServer.start();
  }

  @override
  Future<void> onRepeatEvent(DateTime timestamp) async {
    if (!_httpServer.isRunning) {
      await _httpServer.start();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    await _httpServer.stop();
  }
}
