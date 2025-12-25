// Deprecated: this screen was part of the legacy "Konfirmasi Booking" workflow.
// The app now uses the payment-first flow and the dedicated
// PaymentVerificationScreen for admin verification of payments.
//
// To maintain backward compatibility for any existing references,
// this file now shows a short deprecation notice and a navigator
// to the correct screen. It is safe to remove this file after
// confirming all references are updated.

import 'package:flutter/material.dart';
import 'package:geges_smartbarber/screens/admin/payment_verification_screen.dart';

class BookingConfirmationScreen extends StatelessWidget {
  const BookingConfirmationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konfirmasi Booking (Deprecated)')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Layar "Konfirmasi Booking" sudah tidak digunakan lagi.\nGunakan menu "Verifikasi Pembayaran" untuk memproses bukti pembayaran dan menyetujui booking.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentVerificationScreen(),
                  ),
                ),
                child: const Text('Buka Verifikasi Pembayaran'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
