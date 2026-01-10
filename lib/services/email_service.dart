import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class EmailService {
  // --- KONFIGURASI GMAIL SMTP ---
  // Ganti dengan email & App Password Anda
  // Cara dapat App Password:
  // 1. Buka Akun Google -> Keamanan
  // 2. Aktifkan Verifikasi 2 Langkah (2FA)
  // 3. Cari "App Passwords" (Sandi Aplikasi)
  // 4. Buat baru, namai "Geges App", copy password 16 digitnya.
  static const String _username = 'GANTI_DENGAN_EMAIL_ANDA@gmail.com';
  static const String _password = 'GANTI_DENGAN_APP_PASSWORD_16_DIGIT'; 

  // Singleton
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  /// Mengirim Email Sambutan + Pengingat Verifikasi
  Future<void> sendWelcomeEmail(String name, String email) async {
    final message = Message()
      ..from = Address(_username, 'Geges Smart Barber')
      ..recipients.add(email)
      ..subject = 'Selamat Datang di Geges Smart Barber!'
      ..html = '''
        <h1>Halo, $name! 👋</h1>
        <p>Terima kasih telah bergabung.</p>
        <hr>
        <h3 style="color: red;">⚠ PENTING: Verifikasi Akun</h3>
        <p>Link verifikasi resmi telah dikirim oleh sistem Firebase.</p>
        <p><b>Mohon cek folder SPAM / JUNK email Anda jika tidak ada di Inbox.</b></p>
        <p>Anda harus klik link tersebut untuk bisa Login.</p>
        <br>
        <p>Salam,<br>Tim Geges</p>
      ''';

    await _send(message);
  }

  /// Mengirim Email Konfirmasi Pendaftaran Tenant
  Future<void> sendTenantRegistrationEmail(String shopName, String ownerEmail) async {
    final message = Message()
      ..from = Address(_username, 'Geges Smart Barber')
      ..recipients.add(ownerEmail)
      ..subject = 'Pendaftaran Diterima: $shopName'
      ..html = '''
        <h1>Halo Owner $shopName,</h1>
        <p>Pendaftaran kemitraan Anda sedang kami proses.</p>
        <p>Mohon tunggu verifikasi admin dalam 1x24 jam.</p>
        <p>Pantau status pendaftaran di menu Profil aplikasi.</p>
      ''';

    await _send(message);
  }

  // --- COMPATIBILITY (Biarkan kosong agar kode lama tidak error) ---
  Future<void> sendVerificationReminder(String name, String email) async {}

  // --- INTERNAL SENDER ---
  Future<void> _send(Message message) async {
    // FIX: Jangan kirim email jika sedang dalam environment TEST
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      debugPrint('[EmailService] Mode Test terdeteksi. Melewatkan pengiriman email.');
      return;
    }

    if (_username.startsWith('GANTI')) {
      debugPrint('[EmailService] Gagal: Konfigurasi Email/Password belum diset.');
      return;
    }

    try {
      final smtpServer = gmail(_username, _password);
      await send(message, smtpServer);
      debugPrint('[EmailService] Email terkirim ke ${message.recipients.first}');
    } catch (e) {
      debugPrint('[EmailService] Gagal kirim email: $e');
    }
  }
}