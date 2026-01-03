import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Mendapatkan lokasi saat ini dalam format teks (Contoh: "Mejasem, Tegal")
  /// Mengembalikan null jika gagal atau permission ditolak.
  Future<String?> getCurrentLocationAddress() async {
    return await _getLocation().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('LocationService: Global timeout reached.');
        return 'Lokasi tidak ditemukan (Timeout)';
      },
    );
  }

  Future<String?> _getLocation() async {
    try {
      debugPrint('LocationService: Checking service and permissions...');
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

      debugPrint('LocationService: Getting position...');
      // 3. Prioritaskan Last Known Position (Instan)
      Position? position = await Geolocator.getLastKnownPosition();
      
      if (position == null) {
        debugPrint('LocationService: Last known null, getting current position...');
        position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: const Duration(seconds: 4),
            forceLocationManager: true, // Sering lebih stabil di beberapa device Android
          ),
        );
      }

      debugPrint('LocationService: Position found. Geocoding...');

      // 4. Reverse Geocoding dengan Timeout (agar tidak hanging)
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 3));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        debugPrint('LocationService: Placemark found: ${place.locality}');
        
        // Prioritaskan Nama Kota (Locality) sesuai permintaan user
        if (place.locality != null && place.locality!.isNotEmpty) {
          return place.locality!;
        }
        
        // Fallback ke Kabupaten/Kota (SubAdministrativeArea)
        if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) {
          return place.subAdministrativeArea!;
        }

        // Fallback terakhir: Provinsi
        return place.administrativeArea ?? 'Unknown Location';
      }
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
