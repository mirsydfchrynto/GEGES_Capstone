import 'package:flutter/material.dart';
import 'package:geges_smartbarber/services/network_service.dart';

class OfflineScreen extends StatefulWidget {
  const OfflineScreen({super.key});

  @override
  State<OfflineScreen> createState() => _OfflineScreenState();
}

class _OfflineScreenState extends State<OfflineScreen> {
  bool _isChecking = false;

  Future<void> _handleRetry() async {
    setState(() => _isChecking = true);
    
    // Trigger a manual check in NetworkService
    await NetworkService().checkCurrentStatus();
    
    // For visual feedback, we add a small delay
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      setState(() => _isChecking = false);
      
      // ScaffholdMessenger feedback
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memeriksa koneksi...'),
          duration: Duration(seconds: 1),
          backgroundColor: Color(0xFFC3A47B),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color kBrownAccent = Color(0xFFC3A47B);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.5,
            colors: [
              kBrownAccent.withValues(alpha: 0.05),
              Colors.black,
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Illustration/Icon
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kBrownAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.signal_wifi_off_rounded,
                  size: 64,
                  color: kBrownAccent,
                ),
              ),
              const SizedBox(height: 40),
              
              // Text Content
              const Text(
                'Koneksi Terputus',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sepertinya Anda sedang offline. Aplikasi ini membutuhkan koneksi internet untuk sinkronisasi jadwal dan booking.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _handleRetry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                    shadowColor: kBrownAccent.withValues(alpha: 0.4),
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                          ),
                        )
                      : const Text(
                          'Coba Lagi',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Secondary Info
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.white24),
                  const SizedBox(width: 8),
                  const Text(
                    'Periksa WiFi atau Data Seluler Anda',
                    style: TextStyle(
                      color: Colors.white24,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}