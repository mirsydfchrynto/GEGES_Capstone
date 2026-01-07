import 'package:flutter_test/flutter_test.dart';
import 'package:geges_smartbarber/services/location_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mockito/mockito.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Mocking GeolocatorPlatform
class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  
  bool _serviceEnabled = true;
  LocationPermission _permission = LocationPermission.whileInUse;
  Position? _position;

  void setServiceEnabled(bool enabled) => _serviceEnabled = enabled;
  void setPermission(LocationPermission permission) => _permission = permission;
  void setPosition(Position position) => _position = position;

  @override
  Future<bool> isLocationServiceEnabled() async => _serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => _permission;

  @override
  Future<LocationPermission> requestPermission() async => _permission;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => _position;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    if (_position != null) return _position!;
    throw Exception('No position available');
  }
}

void main() {
  late LocationService locationService;
  late MockGeolocatorPlatform mockGeolocator;

  setUp(() {
    mockGeolocator = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocator;
    locationService = LocationService();
  });

  group('LocationService Tests', () {
    test('Returns "GPS Mati" when location service is disabled', () async {
      mockGeolocator.setServiceEnabled(false);
      
      final result = await locationService.getCurrentLocationAddress();
      
      expect(result, 'GPS Mati');
    });

    test('Returns "Izin Ditolak" when permission is denied', () async {
      mockGeolocator.setServiceEnabled(true);
      mockGeolocator.setPermission(LocationPermission.denied);
      
      final result = await locationService.getCurrentLocationAddress();
      
      expect(result, 'Izin Ditolak');
    });

    test('Returns "Izin Permanen Ditolak" when permission is denied forever', () async {
      mockGeolocator.setServiceEnabled(true);
      mockGeolocator.setPermission(LocationPermission.deniedForever);
      
      final result = await locationService.getCurrentLocationAddress();
      
      expect(result, 'Izin Permanen Ditolak');
    });

    test('Returns fallback coordinates when Geocoding fails (Network Error)', () async {
      mockGeolocator.setServiceEnabled(true);
      mockGeolocator.setPermission(LocationPermission.always);
      mockGeolocator.setPosition(Position(
        longitude: 106.8456,
        latitude: -6.2088,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 0.0,
        heading: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0, 
        altitudeAccuracy: 0.0, 
        headingAccuracy: 0.0,
        isMocked: false
      ));

      // Note: We cannot easily mock static Geocoding.placemarkFromCoordinates without a wrapper 
      // or GeocodingPlatform interface (which is harder to setup for a quick test).
      // However, since we are running in a unit test environment, the real Geocoding platform channel 
      // is not available, so it will throw a MissingPluginException or similar.
      // Our Service catches errors and should return the fallback string.
      
      final result = await locationService.getCurrentLocationAddress();
      
      // The service catches the error and returns: "Lokasi (Lat: -6.21)"
      expect(result, contains('Lokasi (Lat: -6.21)'));
    });
  });
}
