import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/app_localizations.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Заголовок приложения для системы (например, в переключателе задач
      // Android). Локализуется динамически через AppLocalizations —
      // на русском "Погода+", на английском "Weather+", на армянском
      // "Եղանակ+" и т.д. Название под иконкой на главном экране берётся
      // отдельно, из android/app/src/main/res/values*/strings.xml
      // (тоже локализовано на en/ru/hy).
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      // Локализация интерфейса: язык подхватывается автоматически из
      // локали устройства (см. AppLocalizations.delegate). Если язык
      // устройства не входит в supportedLocales, используется английский.
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}
