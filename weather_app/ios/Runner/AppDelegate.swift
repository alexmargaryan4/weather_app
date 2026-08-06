import Flutter
import UIKit
import workmanager
import flutter_local_notifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Регистрация идентификаторов фоновых задач Workmanager — обязательна
    // на iOS (в отличие от Android), должна произойти здесь, до
    // возврата из didFinishLaunching, и идентификаторы должны совпадать
    // один-в-один со списком в Info.plist -> BGTaskSchedulerPermittedIdentifiers,
    // иначе система молча отклоняет регистрацию задачи со стороны Dart.
    WorkmanagerPlugin.registerBGProcessingTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundProcessing")
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "be.tramckrijte.workmanagerExample.iOSBackgroundAppRefresh",
      frequency: NSNumber(value: 15 * 60))
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    // Требуется flutter_local_notifications, чтобы обработчики нажатий на
    // уведомления и фоновые действия имели доступ к зарегистрированным
    // плагинам в отдельном isolate — без этого коллбэка уведомления
    // приходят, но тап по ним/фоновые действия не будут работать.
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
