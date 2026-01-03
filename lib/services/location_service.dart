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
          timeLimit: Duration(seconds: 5),
        ),
      );

      // 4. Reverse Geocoding dengan Timeout (agar tidak hanging)
      // Gunakan timeout 3 detik untuk geocoding
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      ).timeout(const Duration(seconds: 3));

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        // Format: "Kecamatan, Kota" (atau sesuaikan kebutuhan)
        // SubLocality = Kecamatan/Kelurahan, Locality = Kota/Kabupaten
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        
        if (subLocality.isNotEmpty && locality.isNotEmpty) {
          return '$subLocality, $locality';
        } else if (locality.isNotEmpty) {
          return locality;
        } else {
          return subLocality;
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }
}
