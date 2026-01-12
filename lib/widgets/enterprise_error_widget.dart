import 'package:flutter/material.dart';

class EnterpriseErrorWidget extends StatelessWidget {
  final FlutterErrorDetails details;
  const EnterpriseErrorWidget({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    const Color kBrownAccent = Color(0xFFC3A47B);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.auto_fix_off_rounded,
                  size: 64,
                  color: kBrownAccent,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Terjadi Kendala Teknis',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Mohon maaf, sistem kami sedang mengalami kendala visual. Tim teknis kami telah menerima laporan ini.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    // Logic to restart app or go back
                    // In many cases, a simple rebuild might work if it was a transient error
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Coba Muat Ulang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
