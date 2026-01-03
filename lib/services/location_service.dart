import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Mendapatkan lokasi saat ini dalam format teks (Contoh: "Mejasem, Tegal")
  /// Mengembalikan null jika gagal atau permission ditolak.
  Future<String?> getCurrentLocationAddress() async {
    try {
      // 1. Cek apakah GPS aktif
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      // 2. Cek permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return null;
      }

      // 3. Prioritaskan Last Known Position (Instan)
      Position? position = await Geolocator.getLastKnownPosition();
      
      // Jika tidak ada, baru minta Current Position (lebih lambat)
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 3),
        ),
      );

      // 4. Reverse Geocoding dengan Timeout (agar tidak hanging)
      // Timeout dipercepat jadi 2 detik
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 2));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        
        // Prioritaskan Nama Kota (Locality) sesuai permintaan user
        if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        }
        
        // Fallback ke Kabupaten/Kota (SubAdministrativeArea)
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          return place.subAdministrativeArea!;
        }

        // Fallback terakhir: Provinsi
        return place.administrativeArea ?? '';
      }
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
