import 'package:geolocator/geolocator.dart';

class LocationService {
  // Проверяет разрешения и возвращает текущие координаты пользователя
  Future<Position> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Проверяем, включена ли геолокация на устройстве
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Службы геолокации отключены. Включите их в настройках.');
    }

    // Проверяем разрешение
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Доступ к геолокации отклонён пользователем.');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Доступ к геолокации заблокирован навсегда. Разрешите в настройках телефона.');
    }

    // Получаем текущие координаты
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }
}