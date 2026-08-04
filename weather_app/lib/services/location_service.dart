import 'package:geolocator/geolocator.dart';

/// Виды ошибок геолокации. Как и WeatherServiceException, сервис не хранит
/// готовый текст сообщения — локализованный текст подбирается в UI-слое
/// через AppLocalizations по коду ошибки.
enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationServiceException implements Exception {
  final LocationErrorType type;

  LocationServiceException(this.type);

  @override
  String toString() => 'LocationServiceException($type)';
}

class LocationService {
  // Проверяет разрешения и возвращает текущие координаты пользователя
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем, включена ли геолокация на устройстве
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw LocationServiceException(LocationErrorType.serviceDisabled);
    }

    // Проверяем разрешение
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw LocationServiceException(LocationErrorType.permissionDenied);
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw LocationServiceException(LocationErrorType.permissionDeniedForever);
    }

    // Получаем текущие координаты. Точность повышена до high — при medium
    // GPS может давать разброс в сотни метров, из-за чего OpenWeatherMap
    // при обратном геокодинге иногда "перескакивает" на соседний ближайший
    // населённый пункт вместо того, где пользователь на самом деле находится.
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }
}