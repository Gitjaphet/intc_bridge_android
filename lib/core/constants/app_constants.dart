class AppConstants {
  // Serveur HTTP local
  static const int httpPort = 8080;
  static const String appName = 'INTC Bridge';
  static const String appVersion = '1.0.0';

  // Notification foreground service
  static const int notificationId = 1001;
  static const String notificationChannelId = 'intc_bridge_channel';
  static const String notificationChannelName = 'INTC Bridge Service';
  static const String notificationTitle = 'INTC Bridge actif';
  static const String notificationText = 'Serveur d\'impression en écoute sur le port $httpPort';
}
