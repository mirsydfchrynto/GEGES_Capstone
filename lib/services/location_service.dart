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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return 'GPS Mati';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permissions are denied');
          return 'Izin Ditolak';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permissions are permanently denied.');
        return 'Izin Permanen Ditolak';
      }

      debugPrint('LocationService: Getting position...');
      // Coba Last Known Position dulu untuk kecepatan
      Position? position = await Geolocator.getLastKnownPosition();
      
      // Jika null, ambil Current Position dengan timeout yang wajar
      if (position == null) {
        debugPrint('LocationService: Last known null, getting current position...');
        try {
          position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high, // Gunakan high agar lebih akurat
              timeLimit: Duration(seconds: 10), // Timeout 10 detik
            ),
          );
        } catch (e) {
           debugPrint("Error getting current position: $e");
           return 'Gagal Deteksi';
        }
      }

      if (position == null) return 'Lokasi Null';

      debugPrint('LocationService: Position found (${position.latitude}, ${position.longitude}). Geocoding...');

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          debugPrint('LocationService: Placemark found: ${place.locality}');
          
          if ((place.locality ?? '').isNotEmpty) {
            return place.locality;
          }
          if ((place.subAdministrativeArea ?? '').isNotEmpty) {
            return place.subAdministrativeArea;
          }
          return place.administrativeArea ?? 'Indonesia';
        }
      } catch (e) {
        debugPrint("Geocoding error: $e");
        // Fallback jika geocoding gagal (misal tidak ada internet)
        return "Lokasi (Lat: ${position.latitude.toStringAsFixed(2)})";
      }
      return 'Tidak Dikenali';
    } catch (e) {
      debugPrint('Error getting location: $e');
      return 'Error System';
    }
  }

  /// Mendapatkan objek Position (Lat/Lng) mentah
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint("Error getting position: $e");
      return null;
    }
  }

  /// Mengubah alamat string menjadi koordinat (Geocoding)
  Future<Location?> getCoordinatesFromAddress(String address) async {
    try {
      if (address.isEmpty) return null;
      List<Location> locations = await locationFromAddress(address);
      if (locations.isNotEmpty) return locations.first;
      return null;
    } catch (e) {
      // debugPrint("Geocoding error for '$address': $e");
      return null;
    }
  }

  /// Menghitung jarak dalam meter, lalu format ke String (misal: 1.2 km)
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
  }

  /// Hitung jarak antara user dan toko
  Future<String?> calculateDistanceToShop(Position userPos, String shopAddress) async {
    final shopLoc = await getCoordinatesFromAddress(shopAddress);
    if (shopLoc == null) return null;

    final double distanceInMeters = Geolocator.distanceBetween(
      userPos.latitude, 
      userPos.longitude, 
      shopLoc.latitude, 
      shopLoc.longitude
    );
    
    return formatDistance(distanceInMeters);
  }
}
