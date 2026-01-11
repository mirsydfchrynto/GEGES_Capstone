// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Indonesian (`id`).
class AppLocalizationsId extends AppLocalizations {
  AppLocalizationsId([String locale = 'id']) : super(locale);

  @override
  String get appTitle => 'Geges Smart Barber';

  @override
  String get welcome => 'Selamat Datang di GEGES';

  @override
  String get login => 'Masuk';

  @override
  String get signUp => 'Daftar';

  @override
  String get email => 'Email';

  @override
  String get password => 'Kata Sandi';

  @override
  String get forgotPassword => 'Lupa Kata Sandi?';

  @override
  String get continueWithGoogle => 'Lanjutkan dengan Google';

  @override
  String get home => 'Beranda';

  @override
  String get profile => 'Profil';

  @override
  String get settings => 'Pengaturan';

  @override
  String get notifications => 'Notifikasi';

  @override
  String get searchHint => 'Cari Barbershop atau Layanan';

  @override
  String get bookNow => 'Pesan Sekarang';

  @override
  String get waitingForPayment => 'Menunggu Pembayaran';

  @override
  String get verificationPending => 'Menunggu Verifikasi Admin';

  @override
  String get bookingSuccess => 'Booking Berhasil';

  @override
  String get cancel => 'Batal';

  @override
  String get saveChanges => 'Simpan Perubahan';

  @override
  String get registerErrAllFields => 'Semua field wajib diisi.';

  @override
  String get registerErrNameMin => 'Nama minimal 3 karakter.';

  @override
  String get registerErrEmailFormat => 'Format email tidak valid.';

  @override
  String get registerErrPasswordMismatch =>
      'Password dan konfirmasi tidak cocok.';

  @override
  String get registerErrPasswordMin => 'Password minimal 6 karakter.';

  @override
  String get registerMsgSuccess => 'Registrasi Berhasil!';

  @override
  String get registerMsgGoogleSuccess => 'Login Google Berhasil!';

  @override
  String get myLocation => 'Lokasi Saya';

  @override
  String get locating => 'Menentukan lokasi...';

  @override
  String get locationNotFound => 'Lokasi tidak ditemukan';

  @override
  String get locationError => 'Error lokasi';

  @override
  String get barbershopsNearYou => 'Barbershop\ndi dekatmu';

  @override
  String get failedToLoadShops => 'Gagal memuat barbershop.';

  @override
  String foundResults(int count) {
    return 'Ditemukan $count hasil';
  }

  @override
  String get styleScan => 'StyleScan';

  @override
  String get chatbot => 'Chatbot';

  @override
  String get profileTab => 'Profil';

  @override
  String get signOut => 'Keluar';

  @override
  String get language => 'Bahasa';

  @override
  String get changeLanguage => 'Ganti Bahasa';

  @override
  String get paymentTitle => 'Pembayaran';

  @override
  String get totalBill => 'Total Tagihan';

  @override
  String get transferTo => 'Transfer Ke';

  @override
  String get paymentProof => 'Bukti Transfer';

  @override
  String get tapToUpload => 'Ketuk untuk Unggah Bukti';

  @override
  String get uploadLocked => 'Upload Terkunci';

  @override
  String get sendProof => 'Kirim Konfirmasi';

  @override
  String get sending => 'Mengirim...';

  @override
  String get verifying => 'Sedang Diverifikasi';

  @override
  String get paymentRejected => 'Bukti Ditolak';

  @override
  String get timeOut => 'Waktu Habis';

  @override
  String get paymentAccepted => 'Pembayaran Berhasil!';

  @override
  String get paymentSuccessDesc =>
      'Terima kasih! Pembayaran Anda telah kami terima dan pesanan Anda sedang diproses.';

  @override
  String get backToHome => 'Kembali ke Beranda';

  @override
  String get paymentSteps => 'Langkah Pembayaran:';

  @override
  String get paymentStep1 =>
      'Lakukan transfer tepat sesuai nominal ke rekening di atas.';

  @override
  String get paymentStep2 =>
      'Simpan bukti transfer atau screenshot hasil transaksi.';

  @override
  String get paymentStep3 =>
      'Unggah foto bukti tersebut pada kolom di bawah ini.';

  @override
  String get paymentStep4 =>
      'Klik tombol \'Kirim Konfirmasi\' dan tunggu verifikasi admin (1-5 menit).';

  @override
  String get itemDetails => 'Rincian Pesanan';

  @override
  String get orderId => 'ID Pesanan';

  @override
  String get copySuccess => 'Berhasil disalin!';

  @override
  String get payBefore => 'Bayar sebelum';

  @override
  String get welcomeSubtitle => 'Masuk atau buat akun untuk memulai.';

  @override
  String get signInTab => 'Masuk';

  @override
  String get orSplit => 'atau';

  @override
  String get termFooterPre => 'Dengan melanjutkan, Anda setuju dengan';

  @override
  String get termFooterService => 'Syarat Layanan';

  @override
  String get termFooterAnd => ' dan ';

  @override
  String get termFooterPrivacy => 'Kebijakan Privasi';

  @override
  String get errLoginEmpty => 'Email dan kata sandi wajib diisi.';

  @override
  String get errEmailFormat => 'Format email salah.';

  @override
  String get errLoginFailed => 'Login gagal.';

  @override
  String errGeneric(String error) {
    return 'Terjadi kesalahan: $error';
  }

  @override
  String errRoleInvalid(String role) {
    return 'Peran pengguna tidak valid: $role';
  }

  @override
  String msgResetSent(String email) {
    return 'Link reset kata sandi telah dikirim ke $email.';
  }

  @override
  String get msgResetFail => 'Gagal mengirim link reset kata sandi.';

  @override
  String get dialogResetTitle => 'Reset Kata Sandi';

  @override
  String get dialogResetHint => 'Masukkan email Anda';

  @override
  String get dialogResetCancel => 'Batal';

  @override
  String get btnSend => 'Kirim';

  @override
  String get btnRetry => 'Coba Lagi';

  @override
  String get troubleshootTitle => 'Pemecahan Masalah Masuk';

  @override
  String get strengthWeak => 'Lemah';

  @override
  String get strengthMedium => 'Sedang';

  @override
  String get strengthStrong => 'Kuat';

  @override
  String get strengthLabel => 'Kekuatan Kata Sandi: ';

  @override
  String get username => 'Nama Pengguna';

  @override
  String get confirmPassword => 'Konfirmasi Kata Sandi';

  @override
  String get createAccount => 'Buat Akun';

  @override
  String get troubleshootContent =>
      'Jika Anda melihat pesan reCAPTCHA atau Developer Error, periksa langkah-langkah berikut:\n- Pastikan SHA-1 debug/release ditambahkan ke Firebase Console\n- Ganti google-services.json bila diperlukan dan rebuild aplikasi\n- Untuk masalah reCAPTCHA, coba login dengan email/password sebagai fallback\n- App Check dapat diabaikan pada development atau dikonfigurasi untuk production';

  @override
  String get btnClose => 'Tutup';

  @override
  String get shopClosed => 'TUTUP / CLOSED';

  @override
  String noResultsFor(String query) {
    return 'Tidak ditemukan hasil untuk \"$query\"';
  }

  @override
  String get history => 'Riwayat';

  @override
  String get favoriteBarbers => 'Barber Favorit';

  @override
  String get appRating => 'Rating Aplikasi';

  @override
  String get termsOfService => 'Syarat Layanan';

  @override
  String get promoGrowTitle => 'Kembangkan Barbershop Anda bersama kami';

  @override
  String get promoGrowSubtitle =>
      'Bergabunglah dengan jaringan Barber Profesional kami';

  @override
  String get registerMyBarbershop => 'Daftarkan Barbershop Saya';

  @override
  String get copiedToClipboard => 'Disalin ke clipboard';

  @override
  String get loading => 'Memuat...';

  @override
  String get searchHintHome => 'Cari Barbershop atau Layanan';

  @override
  String get editProfile => 'Edit Profil';

  @override
  String get fullName => 'Nama Lengkap';

  @override
  String get phoneNumber => 'Nomor Telepon';

  @override
  String get requiredField => 'Wajib diisi';

  @override
  String get invalidEmail => 'Email tidak valid';

  @override
  String get saveChangesBtn => 'SIMPAN PERUBAHAN';

  @override
  String errPickImage(String error) {
    return 'Gagal mengambil gambar: $error';
  }

  @override
  String get confirmPasswordTitle => 'Konfirmasi Kata Sandi';

  @override
  String get enterPasswordHint => 'Masukkan kata sandi Anda';

  @override
  String get continueBtn => 'Lanjut';

  @override
  String get errReauthFailed => 'Autentikasi ulang gagal.';

  @override
  String get errUpdateProfile => 'Gagal memperbarui profil.';

  @override
  String get verifyNewEmailTitle => 'Verifikasi Email Baru';

  @override
  String verifyNewEmailMsg(String email) {
    return 'Kami telah mengirimkan link verifikasi ke:\n\n$email\n\nSilakan buka email tersebut.';
  }

  @override
  String get ok => 'Oke';

  @override
  String get styleScanTitle => 'Scan Gaya Rambut AI';

  @override
  String get takePhoto => 'Ambil Foto';

  @override
  String get uploadImage => 'Unggah Gambar';

  @override
  String get scanResultTitle => 'Hasil Scan Gaya';

  @override
  String get aiAnalysis => 'Analisis AI:';

  @override
  String get detectedStyle => 'Gaya Terdeteksi:';

  @override
  String get confidence => 'Kecocokan:';

  @override
  String get faceShape => 'Bentuk Wajah:';

  @override
  String get descriptionLabel => 'Deskripsi:';

  @override
  String get bookWithThisStyle => 'Book Barbershop dengan Gaya Ini';

  @override
  String get rescan => 'Scan Ulang / Ambil Gambar Baru';

  @override
  String errScanFailed(String error) {
    return 'Gagal scan: $error';
  }

  @override
  String get cameraAccessDenied => 'Akses Kamera ditolak.';

  @override
  String get galleryAccessDenied => 'Akses Galeri ditolak.';

  @override
  String get chatTitle => 'GIA - GEGES Intelligent Assistant';

  @override
  String get giaGreeting =>
      'Halo! Saya GIA, asisten virtual GEGES. Ada yang bisa saya bantu?';

  @override
  String get errMustLoginChat =>
      'Silakan login terlebih dahulu untuk mengecek antrian.';

  @override
  String get noActiveBookings =>
      'Anda belum memiliki booking aktif saat ini. Yuk buat booking baru!';

  @override
  String activeBookingDesc(String date, String status, String shopId) {
    return 'Booking aktif Anda:\n📅 $date\n🔖 Status: $status\n📍 Barbershop ID: $shopId';
  }

  @override
  String get errCheckQueueFailed =>
      'Maaf, saya gagal mengecek data antrian Anda. Coba lagi nanti.';

  @override
  String get errNoStylesAvailable =>
      'Maaf, data gaya rambut sedang tidak tersedia.';

  @override
  String get popularServicesHeader => 'Berikut beberapa layanan populer kami:';

  @override
  String get errLoadRecommendationFailed => 'Gagal memuat rekomendasi.';

  @override
  String get branchInfo =>
      'Kami memiliki banyak cabang! Gunakan fitur \'Lokasi Saya\' di halaman Home untuk menemukan yang terdekat.';

  @override
  String get giaFallback =>
      'Maaf, saya belum mengerti. Coba kata kunci: \'antrian saya\', \'rekomendasi gaya\', atau \'alamat\'.';

  @override
  String get giaTyping => 'GIA sedang mengetik...';

  @override
  String get chatMinutes => 'menit';

  @override
  String get seeDetail => 'Lihat Detail';

  @override
  String get chatHint => 'Tulis pesan...';

  @override
  String get stepService => 'Layanan';

  @override
  String get stepBarber => 'Barber';

  @override
  String get stepSchedule => 'Jadwal';

  @override
  String get selectServiceTitle => 'Pilih Layanan';

  @override
  String get selectServiceSubtitle =>
      'Anda bisa memilih lebih dari satu layanan';

  @override
  String get whoCutsTitle => 'Siapa yang mencukur?';

  @override
  String get barberChoiceSystem => 'Dipilihkan Sistem (Adil & Cepat)';

  @override
  String get barberChoiceSystemDesc =>
      'Sistem akan mencarikan barber terbaik yang tersedia untuk Anda.';

  @override
  String get barberChoiceFavorite => 'Pilih Barber Favorit';

  @override
  String barberChoiceFavoriteDesc(String fee) {
    return 'Pilih barber tertentu yang sudah Anda kenal (+ Rp $fee)';
  }

  @override
  String get specialistList => 'Daftar Specialist';

  @override
  String get scheduleTitle => 'Tentukan Jadwal';

  @override
  String get pickDay => 'Pilih Hari';

  @override
  String get pickTime => 'Pilih Jam';

  @override
  String get shopHoliday => 'LIBUR';

  @override
  String get totalEst => 'Total Estimasi';

  @override
  String get btnNext => 'LANJUT';

  @override
  String get btnBookNow => 'BOOK NOW';

  @override
  String get confirmBookingTitle => 'Konfirmasi Booking';

  @override
  String get labelDate => 'Tanggal';

  @override
  String get labelTime => 'Jam';

  @override
  String get labelBarber => 'Barber';

  @override
  String get labelTotalCost => 'Total Biaya';

  @override
  String get btnCancel => 'Batal';

  @override
  String get btnConfirmBook => 'Booking Sekarang';

  @override
  String get errPickService => 'Pilih minimal satu layanan';

  @override
  String get errPickBarber => 'Silakan pilih barber favorit Anda';

  @override
  String get errPickBarberFirst => 'Pilih barber terlebih dahulu';

  @override
  String get errBarberBusy => 'Barber tersebut sudah ada jadwal di jam ini';

  @override
  String get errNoFairBarber =>
      'Tidak ada hairstylist tersedia jam ini. Coba jam lain.';

  @override
  String errShopClosed(String shopName) {
    return '$shopName Sedang Tutup';
  }

  @override
  String get errShopClosedDesc =>
      'Maaf, barbershop ini sedang tidak menerima pesanan.\nSilakan cek kembali nanti.';

  @override
  String barberOffDay(String name) {
    return '$name libur pada tanggal ini.';
  }

  @override
  String get barberOffDayDesc => 'Silakan pilih tanggal lain atau barber lain.';

  @override
  String get randomSystem => 'Sistem Acak';

  @override
  String get myOrders => 'Pesanan Saya';

  @override
  String get tabUnpaid => 'Belum Bayar';

  @override
  String get tabScheduled => 'Terjadwal';

  @override
  String get tabProcessing => 'Sedang Proses';

  @override
  String get tabCompleted => 'Selesai';

  @override
  String get tabCancelled => 'Dibatalkan';

  @override
  String get loginRequired => 'Wajib login';

  @override
  String get noOrders => 'Tidak ada pesanan';

  @override
  String get statusUnpaid => 'BELUM BAYAR';

  @override
  String get statusCancelled => 'DIBATALKAN';

  @override
  String get statusCancelRequested => 'PERMOHONAN PEMBATALAN';

  @override
  String get statusCompleted => 'SELESAI';

  @override
  String get statusProcessing => 'SEDANG DIPROSES';

  @override
  String get statusScheduled => 'TERJADWAL';

  @override
  String get statusPendingVerification => 'MENUNGGU VERIFIKASI';

  @override
  String get specialOrders => 'Pesanan Khusus';

  @override
  String get pleaseLoginFirst => 'Silakan login terlebih dahulu';

  @override
  String errLoadingOrders(String error) {
    return 'Gagal memuat pesanan: $error';
  }

  @override
  String get noSpecialOrders => 'Belum ada Pesanan Khusus';

  @override
  String get statusAwaitingPayment => 'Menunggu Pembayaran';

  @override
  String get descAwaitingPayment =>
      'Selesaikan pembayaran untuk memproses pendaftaran.';

  @override
  String get statusActivePartnership => 'SUKSES / AKTIF';

  @override
  String get descActivePartnership => 'Selamat! Partnership Anda telah aktif.';

  @override
  String get statusCancelledRejected => 'DIBATALKAN / DITOLAK';

  @override
  String get descCancelledRejected => 'Permintaan ini tidak dapat diproses.';

  @override
  String get statusWaitingVerification => 'MENUNGGU VERIFIKASI';

  @override
  String get descWaitingVerification =>
      'Bukti diterima. Admin sedang memverifikasi data Anda.';

  @override
  String get btnResumePayment => 'LANJUTKAN PEMBAYARAN';

  @override
  String get registrationIncompleteTitle => 'Pendaftaran Belum Selesai';

  @override
  String get registrationIncompleteMsg =>
      'Anda belum mengunggah bukti pembayaran. Data pendaftaran Anda tersimpan sebagai \'Menunggu Pembayaran\' dan bisa dilanjutkan nanti.';

  @override
  String get btnCancelExit => 'Batal Keluar';

  @override
  String get btnExitSaveDraft => 'Keluar (Simpan Draft)';

  @override
  String get btnCancelRegistration => 'Batalkan Pendaftaran';

  @override
  String get registrationDetail => 'Detail Pendaftaran';

  @override
  String get cancelRegistrationTitle => 'Batalkan Pendaftaran?';

  @override
  String get cancelRegistrationWarning =>
      'Jika Anda membatalkan pendaftaran yang SUDAH DIBAYAR, dana akan dikembalikan dengan POTONGAN 10% (biaya admin).\n\nApakah Anda yakin?';

  @override
  String get btnBack => 'Kembali';

  @override
  String get btnYesCancel => 'Ya, Batalkan';

  @override
  String get msgCancelSent => 'Permintaan pembatalan dikirim.';

  @override
  String errCancelFailed(String error) {
    return 'Gagal membatalkan: $error';
  }

  @override
  String get errOpenWhatsApp => 'Gagal membuka WhatsApp support';

  @override
  String get statusActiveCompleted => 'AKTIF / SELESAI';

  @override
  String get statusRefundProcessing => 'REFUND DIPROSES';

  @override
  String get businessInfo => 'Informasi Bisnis';

  @override
  String get barbershopName => 'Nama Barbershop';

  @override
  String get subscriptionPlan => 'Paket Langganan';

  @override
  String get registrationFee => 'Biaya Pendaftaran';

  @override
  String get address => 'Alamat';

  @override
  String get adminAccountTitle => 'Akun Admin Barbershop';

  @override
  String get adminAccountDesc =>
      'Gunakan akun ini untuk login ke Aplikasi Admin:';

  @override
  String get btnLogoutLoginAdmin => 'LOGOUT & LOGIN SEBAGAI ADMIN';

  @override
  String get contactAdmin => 'Hubungi Admin';

  @override
  String get changePassword => 'Ganti Password';

  @override
  String get loginAsAdminTitle => 'Login sebagai Admin?';

  @override
  String get loginAsAdminMsg =>
      'Anda akan keluar dari akun Customer ini.\n\nSilakan gunakan Email & Password yang tertera di atas untuk login kembali sebagai Owner Barbershop.';

  @override
  String get btnYesLogout => 'Ya, Logout';

  @override
  String get cancelDetail => 'Detail Pembatalan';

  @override
  String get reason => 'Alasan';

  @override
  String get viewRefundProof => 'Lihat Bukti Refund';

  @override
  String get btnPayNow => 'BAYAR SEKARANG';

  @override
  String get contactSupport => 'Hubungi Bantuan / Komplain';

  @override
  String get statusRefundWaiting => 'MENUNGGU PROSES REFUND';

  @override
  String get statusRefundCompleted => 'DIBATALKAN & REFUND SELESAI';

  @override
  String get btnRequestRefund => 'Batalkan & Minta Refund';

  @override
  String get descRefundWaiting =>
      'Permintaan pembatalan Anda sedang ditinjau admin. Dana akan dikembalikan sesuai kebijakan.';

  @override
  String get adminNote => 'Catatan Admin';
}
