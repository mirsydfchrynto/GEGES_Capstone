import 'package:flutter/material.dart';

class TenantGuideDialog extends StatelessWidget {
  const TenantGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    const Color kBrownAccent = Color(0xFFC3A47B);
    const Color kDarkGrey = Color(0xFF1E1E1E);

    return Dialog(
      backgroundColor: kDarkGrey,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: kBrownAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.store_rounded, color: kBrownAccent, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Alur Menjadi Mitra',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              const Text(
                'Selamat datang calon Mitra Geges Smart Barber! Mohon pahami alur pendaftaran berikut agar proses verifikasi berjalan lancar:',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),

              // Alur Pendaftaran
              _buildSectionTitle('Langkah Pendaftaran:'),
              const SizedBox(height: 12),
              _buildStep(
                number: '1',
                title: 'Gunakan Email BARU',
                description: 'Anda WAJIB menggunakan email (Google) yang BELUM PERNAH terdaftar di aplikasi ini sebagai pelanggan. Email ini akan menjadi akun ADMIN/OWNER Barbershop Anda.',
              ),
              const SizedBox(height: 16),
              _buildStep(
                number: '2',
                title: 'Data & Dokumen SIUP/NPWP',
                description: 'Isi data bisnis dengan lengkap. Siapkan file SIUP (Surat Izin Usaha) dan NPWP dalam format gambar/PDF (maksimal 900KB).',
              ),
              const SizedBox(height: 16),
              _buildStep(
                number: '3',
                title: 'Pembayaran & Verifikasi',
                description: 'Lakukan pembayaran biaya registrasi. Admin akan memverifikasi data Anda dalam 1-3 hari kerja.',
              ),
              const SizedBox(height: 16),
              _buildStep(
                number: '4',
                title: 'Terima Password Admin',
                description: 'Jika disetujui, Admin akan mengirimkan Password Login via Notifikasi dan Email. Anda bisa login ke Aplikasi Khusus Owner (Geges Admin).',
              ),
              
              const SizedBox(height: 24),
              const Divider(color: Colors.white24),
              const SizedBox(height: 16),

              // Manajemen Bisnis
              _buildSectionTitle('Setelah Aktif, Anda Bisa Mengelola:'),
              const SizedBox(height: 12),
              _buildManagementItem(Icons.people, 'Karyawan / Barberman', 'Atur jam kerja, off-day, dan performa karyawan.'),
              _buildManagementItem(Icons.content_cut, 'Layanan & Harga', 'Tentukan jenis potongan rambut dan harga sesuai lokasi Anda.'),
              _buildManagementItem(Icons.list_alt, 'Antrean Real-time', 'Pantau antrean masuk secara langsung dari HP Anda.'),
              _buildManagementItem(Icons.analytics, 'Laporan Keuangan', 'Rekap pendapatan harian dan bulanan otomatis.'),

              const SizedBox(height: 32),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'LANJUT DAFTAR',
                    style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Klik di luar untuk menutup panduan',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Color(0xFFC3A47B),
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildStep({required String number, required String title, required String description}) {
    const Color kBrownAccent = Color(0xFFC3A47B);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: kBrownAccent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: kBrownAccent.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildManagementItem(IconData icon, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                children: [
                  TextSpan(
                    text: '$title: ',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}