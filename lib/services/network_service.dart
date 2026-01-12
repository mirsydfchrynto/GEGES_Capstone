import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

enum NetworkStatus { online, offline }

class NetworkService {
  // Singleton pattern
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetChecker = InternetConnection();
  
  final StreamController<NetworkStatus> _controller = StreamController<NetworkStatus>.broadcast();
  Stream<NetworkStatus> get stream => _controller.stream;

  void init() {
    // Listen to connectivity changes (WiFi, Mobile, None)
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
      _checkInternetConnection(results);
    });
    
    // Initial check
    checkCurrentStatus();
  }

  Future<void> checkCurrentStatus() async {
    final results = await _connectivity.checkConnectivity();
    await _checkInternetConnection(results);
  }

  Future<void> _checkInternetConnection(List<ConnectivityResult> results) async {
    if (results.contains(ConnectivityResult.none) && results.length == 1) {
      _controller.add(NetworkStatus.offline);
      return;
    }

    // Even if connected to WiFi, check if we actually have internet
    final hasInternet = await _internetChecker.hasInternetAccess;
    if (hasInternet) {
      _controller.add(NetworkStatus.online);
    } else {
      _controller.add(NetworkStatus.offline);
    }
  }

  void dispose() {
    _controller.close();
  }
}
