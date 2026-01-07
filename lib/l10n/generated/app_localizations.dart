import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id')
  ];

  /// No description provided for @appTitle.
  ///
  /// In id, this message translates to:
  /// **'Geges Smart Barber'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In id, this message translates to:
  /// **'Selamat Datang di GEGES'**
  String get welcome;

  /// No description provided for @login.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get login;

  /// No description provided for @signUp.
  ///
  /// In id, this message translates to:
  /// **'Daftar'**
  String get signUp;

  /// No description provided for @email.
  ///
  /// In id, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In id, this message translates to:
  /// **'Kata Sandi'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In id, this message translates to:
  /// **'Lupa Kata Sandi?'**
  String get forgotPassword;

  /// No description provided for @continueWithGoogle.
  ///
  /// In id, this message translates to:
  /// **'Lanjutkan dengan Google'**
  String get continueWithGoogle;

  /// No description provided for @home.
  ///
  /// In id, this message translates to:
  /// **'Beranda'**
  String get home;

  /// No description provided for @profile.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In id, this message translates to:
  /// **'Pengaturan'**
  String get settings;

  /// No description provided for @notifications.
  ///
  /// In id, this message translates to:
  /// **'Notifikasi'**
  String get notifications;

  /// No description provided for @searchHint.
  ///
  /// In id, this message translates to:
  /// **'Cari Barbershop atau Layanan'**
  String get searchHint;

  /// No description provided for @bookNow.
  ///
  /// In id, this message translates to:
  /// **'Pesan Sekarang'**
  String get bookNow;

  /// No description provided for @waitingForPayment.
  ///
  /// In id, this message translates to:
  /// **'Menunggu Pembayaran'**
  String get waitingForPayment;

  /// No description provided for @verificationPending.
  ///
  /// In id, this message translates to:
  /// **'Menunggu Verifikasi Admin'**
  String get verificationPending;

  /// No description provided for @bookingSuccess.
  ///
  /// In id, this message translates to:
  /// **'Booking Berhasil'**
  String get bookingSuccess;

  /// No description provided for @cancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get cancel;

  /// No description provided for @saveChanges.
  ///
  /// In id, this message translates to:
  /// **'Simpan Perubahan'**
  String get saveChanges;

  /// No description provided for @registerErrAllFields.
  ///
  /// In id, this message translates to:
  /// **'Semua field wajib diisi.'**
  String get registerErrAllFields;

  /// No description provided for @registerErrNameMin.
  ///
  /// In id, this message translates to:
  /// **'Nama minimal 3 karakter.'**
  String get registerErrNameMin;

  /// No description provided for @registerErrEmailFormat.
  ///
  /// In id, this message translates to:
  /// **'Format email tidak valid.'**
  String get registerErrEmailFormat;

  /// No description provided for @registerErrPasswordMismatch.
  ///
  /// In id, this message translates to:
  /// **'Password dan konfirmasi tidak cocok.'**
  String get registerErrPasswordMismatch;

  /// No description provided for @registerErrPasswordMin.
  ///
  /// In id, this message translates to:
  /// **'Password minimal 6 karakter.'**
  String get registerErrPasswordMin;

  /// No description provided for @registerMsgSuccess.
  ///
  /// In id, this message translates to:
  /// **'Registrasi Berhasil!'**
  String get registerMsgSuccess;

  /// No description provided for @registerMsgGoogleSuccess.
  ///
  /// In id, this message translates to:
  /// **'Login Google Berhasil!'**
  String get registerMsgGoogleSuccess;

  /// No description provided for @myLocation.
  ///
  /// In id, this message translates to:
  /// **'Lokasi Saya'**
  String get myLocation;

  /// No description provided for @locating.
  ///
  /// In id, this message translates to:
  /// **'Menentukan lokasi...'**
  String get locating;

  /// No description provided for @locationNotFound.
  ///
  /// In id, this message translates to:
  /// **'Lokasi tidak ditemukan'**
  String get locationNotFound;

  /// No description provided for @locationError.
  ///
  /// In id, this message translates to:
  /// **'Error lokasi'**
  String get locationError;

  /// No description provided for @barbershopsNearYou.
  ///
  /// In id, this message translates to:
  /// **'Barbershop\ndi dekatmu'**
  String get barbershopsNearYou;

  /// No description provided for @failedToLoadShops.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat barbershop.'**
  String get failedToLoadShops;

  /// No description provided for @foundResults.
  ///
  /// In id, this message translates to:
  /// **'Ditemukan {count} hasil'**
  String foundResults(int count);

  /// No description provided for @styleScan.
  ///
  /// In id, this message translates to:
  /// **'StyleScan'**
  String get styleScan;

  /// No description provided for @chatbot.
  ///
  /// In id, this message translates to:
  /// **'Chatbot'**
  String get chatbot;

  /// No description provided for @profileTab.
  ///
  /// In id, this message translates to:
  /// **'Profil'**
  String get profileTab;

  /// No description provided for @signOut.
  ///
  /// In id, this message translates to:
  /// **'Keluar'**
  String get signOut;

  /// No description provided for @language.
  ///
  /// In id, this message translates to:
  /// **'Bahasa'**
  String get language;

  /// No description provided for @changeLanguage.
  ///
  /// In id, this message translates to:
  /// **'Ganti Bahasa'**
  String get changeLanguage;

  /// No description provided for @paymentTitle.
  ///
  /// In id, this message translates to:
  /// **'Menunggu Pembayaran'**
  String get paymentTitle;

  /// No description provided for @totalBill.
  ///
  /// In id, this message translates to:
  /// **'Total Tagihan'**
  String get totalBill;

  /// No description provided for @transferTo.
  ///
  /// In id, this message translates to:
  /// **'Transfer Ke'**
  String get transferTo;

  /// No description provided for @paymentProof.
  ///
  /// In id, this message translates to:
  /// **'Bukti Transfer'**
  String get paymentProof;

  /// No description provided for @tapToUpload.
  ///
  /// In id, this message translates to:
  /// **'Tap untuk upload foto'**
  String get tapToUpload;

  /// No description provided for @uploadLocked.
  ///
  /// In id, this message translates to:
  /// **'Upload Terkunci'**
  String get uploadLocked;

  /// No description provided for @sendProof.
  ///
  /// In id, this message translates to:
  /// **'Kirim Bukti Pembayaran'**
  String get sendProof;

  /// No description provided for @sending.
  ///
  /// In id, this message translates to:
  /// **'Mengirim...'**
  String get sending;

  /// No description provided for @verifying.
  ///
  /// In id, this message translates to:
  /// **'Sedang Diverifikasi'**
  String get verifying;

  /// No description provided for @paymentRejected.
  ///
  /// In id, this message translates to:
  /// **'Bukti Ditolak'**
  String get paymentRejected;

  /// No description provided for @timeOut.
  ///
  /// In id, this message translates to:
  /// **'Waktu Habis'**
  String get timeOut;

  /// No description provided for @paymentAccepted.
  ///
  /// In id, this message translates to:
  /// **'Pembayaran Diterima!'**
  String get paymentAccepted;

  /// No description provided for @paymentSuccessDesc.
  ///
  /// In id, this message translates to:
  /// **'Terima kasih, booking Anda telah dikonfirmasi. Silakan datang tepat waktu.'**
  String get paymentSuccessDesc;

  /// No description provided for @backToHome.
  ///
  /// In id, this message translates to:
  /// **'Kembali ke Beranda'**
  String get backToHome;

  /// No description provided for @welcomeSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Masuk atau buat akun untuk memulai.'**
  String get welcomeSubtitle;

  /// No description provided for @signInTab.
  ///
  /// In id, this message translates to:
  /// **'Masuk'**
  String get signInTab;

  /// No description provided for @orSplit.
  ///
  /// In id, this message translates to:
  /// **'atau'**
  String get orSplit;

  /// No description provided for @termFooterPre.
  ///
  /// In id, this message translates to:
  /// **'Dengan melanjutkan, Anda setuju dengan'**
  String get termFooterPre;

  /// No description provided for @termFooterService.
  ///
  /// In id, this message translates to:
  /// **'Syarat Layanan'**
  String get termFooterService;

  /// No description provided for @termFooterAnd.
  ///
  /// In id, this message translates to:
  /// **' dan '**
  String get termFooterAnd;

  /// No description provided for @termFooterPrivacy.
  ///
  /// In id, this message translates to:
  /// **'Kebijakan Privasi'**
  String get termFooterPrivacy;

  /// No description provided for @errLoginEmpty.
  ///
  /// In id, this message translates to:
  /// **'Email dan kata sandi wajib diisi.'**
  String get errLoginEmpty;

  /// No description provided for @errEmailFormat.
  ///
  /// In id, this message translates to:
  /// **'Format email salah.'**
  String get errEmailFormat;

  /// No description provided for @errLoginFailed.
  ///
  /// In id, this message translates to:
  /// **'Login gagal.'**
  String get errLoginFailed;

  /// No description provided for @errGeneric.
  ///
  /// In id, this message translates to:
  /// **'Terjadi kesalahan: {error}'**
  String errGeneric(String error);

  /// No description provided for @errRoleInvalid.
  ///
  /// In id, this message translates to:
  /// **'Peran pengguna tidak valid: {role}'**
  String errRoleInvalid(String role);

  /// No description provided for @msgResetSent.
  ///
  /// In id, this message translates to:
  /// **'Link reset kata sandi telah dikirim ke {email}.'**
  String msgResetSent(String email);

  /// No description provided for @msgResetFail.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengirim link reset kata sandi.'**
  String get msgResetFail;

  /// No description provided for @dialogResetTitle.
  ///
  /// In id, this message translates to:
  /// **'Reset Kata Sandi'**
  String get dialogResetTitle;

  /// No description provided for @dialogResetHint.
  ///
  /// In id, this message translates to:
  /// **'Masukkan email Anda'**
  String get dialogResetHint;

  /// No description provided for @dialogResetCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get dialogResetCancel;

  /// No description provided for @btnSend.
  ///
  /// In id, this message translates to:
  /// **'Kirim'**
  String get btnSend;

  /// No description provided for @btnRetry.
  ///
  /// In id, this message translates to:
  /// **'Coba Lagi'**
  String get btnRetry;

  /// No description provided for @troubleshootTitle.
  ///
  /// In id, this message translates to:
  /// **'Pemecahan Masalah Masuk'**
  String get troubleshootTitle;

  /// No description provided for @strengthWeak.
  ///
  /// In id, this message translates to:
  /// **'Lemah'**
  String get strengthWeak;

  /// No description provided for @strengthMedium.
  ///
  /// In id, this message translates to:
  /// **'Sedang'**
  String get strengthMedium;

  /// No description provided for @strengthStrong.
  ///
  /// In id, this message translates to:
  /// **'Kuat'**
  String get strengthStrong;

  /// No description provided for @strengthLabel.
  ///
  /// In id, this message translates to:
  /// **'Kekuatan Kata Sandi: '**
  String get strengthLabel;

  /// No description provided for @username.
  ///
  /// In id, this message translates to:
  /// **'Nama Pengguna'**
  String get username;

  /// No description provided for @confirmPassword.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Kata Sandi'**
  String get confirmPassword;

  /// No description provided for @createAccount.
  ///
  /// In id, this message translates to:
  /// **'Buat Akun'**
  String get createAccount;

  /// No description provided for @troubleshootContent.
  ///
  /// In id, this message translates to:
  /// **'Jika Anda melihat pesan reCAPTCHA atau Developer Error, periksa langkah-langkah berikut:\n- Pastikan SHA-1 debug/release ditambahkan ke Firebase Console\n- Ganti google-services.json bila diperlukan dan rebuild aplikasi\n- Untuk masalah reCAPTCHA, coba login dengan email/password sebagai fallback\n- App Check dapat diabaikan pada development atau dikonfigurasi untuk production'**
  String get troubleshootContent;

  /// No description provided for @btnClose.
  ///
  /// In id, this message translates to:
  /// **'Tutup'**
  String get btnClose;

  /// No description provided for @shopClosed.
  ///
  /// In id, this message translates to:
  /// **'TUTUP / CLOSED'**
  String get shopClosed;

  /// No description provided for @noResultsFor.
  ///
  /// In id, this message translates to:
  /// **'Tidak ditemukan hasil untuk \"{query}\"'**
  String noResultsFor(String query);

  /// No description provided for @history.
  ///
  /// In id, this message translates to:
  /// **'Riwayat'**
  String get history;

  /// No description provided for @favoriteBarbers.
  ///
  /// In id, this message translates to:
  /// **'Barber Favorit'**
  String get favoriteBarbers;

  /// No description provided for @appRating.
  ///
  /// In id, this message translates to:
  /// **'Rating Aplikasi'**
  String get appRating;

  /// No description provided for @termsOfService.
  ///
  /// In id, this message translates to:
  /// **'Syarat Layanan'**
  String get termsOfService;

  /// No description provided for @promoGrowTitle.
  ///
  /// In id, this message translates to:
  /// **'Kembangkan Barbershop Anda bersama kami'**
  String get promoGrowTitle;

  /// No description provided for @promoGrowSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Bergabunglah dengan jaringan Barber Profesional kami'**
  String get promoGrowSubtitle;

  /// No description provided for @registerMyBarbershop.
  ///
  /// In id, this message translates to:
  /// **'Daftarkan Barbershop Saya'**
  String get registerMyBarbershop;

  /// No description provided for @copiedToClipboard.
  ///
  /// In id, this message translates to:
  /// **'Disalin ke clipboard'**
  String get copiedToClipboard;

  /// No description provided for @loading.
  ///
  /// In id, this message translates to:
  /// **'Memuat...'**
  String get loading;

  /// No description provided for @searchHintHome.
  ///
  /// In id, this message translates to:
  /// **'Cari Barbershop atau Layanan'**
  String get searchHintHome;

  /// No description provided for @editProfile.
  ///
  /// In id, this message translates to:
  /// **'Edit Profil'**
  String get editProfile;

  /// No description provided for @fullName.
  ///
  /// In id, this message translates to:
  /// **'Nama Lengkap'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In id, this message translates to:
  /// **'Nomor Telepon'**
  String get phoneNumber;

  /// No description provided for @requiredField.
  ///
  /// In id, this message translates to:
  /// **'Wajib diisi'**
  String get requiredField;

  /// No description provided for @invalidEmail.
  ///
  /// In id, this message translates to:
  /// **'Email tidak valid'**
  String get invalidEmail;

  /// No description provided for @saveChangesBtn.
  ///
  /// In id, this message translates to:
  /// **'SIMPAN PERUBAHAN'**
  String get saveChangesBtn;

  /// No description provided for @errPickImage.
  ///
  /// In id, this message translates to:
  /// **'Gagal mengambil gambar: {error}'**
  String errPickImage(String error);

  /// No description provided for @confirmPasswordTitle.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Kata Sandi'**
  String get confirmPasswordTitle;

  /// No description provided for @enterPasswordHint.
  ///
  /// In id, this message translates to:
  /// **'Masukkan kata sandi Anda'**
  String get enterPasswordHint;

  /// No description provided for @continueBtn.
  ///
  /// In id, this message translates to:
  /// **'Lanjut'**
  String get continueBtn;

  /// No description provided for @errReauthFailed.
  ///
  /// In id, this message translates to:
  /// **'Autentikasi ulang gagal.'**
  String get errReauthFailed;

  /// No description provided for @errUpdateProfile.
  ///
  /// In id, this message translates to:
  /// **'Gagal memperbarui profil.'**
  String get errUpdateProfile;

  /// No description provided for @verifyNewEmailTitle.
  ///
  /// In id, this message translates to:
  /// **'Verifikasi Email Baru'**
  String get verifyNewEmailTitle;

  /// No description provided for @verifyNewEmailMsg.
  ///
  /// In id, this message translates to:
  /// **'Kami telah mengirimkan link verifikasi ke:\n\n{email}\n\nSilakan buka email tersebut.'**
  String verifyNewEmailMsg(String email);

  /// No description provided for @ok.
  ///
  /// In id, this message translates to:
  /// **'Oke'**
  String get ok;

  /// No description provided for @styleScanTitle.
  ///
  /// In id, this message translates to:
  /// **'Scan Gaya Rambut AI'**
  String get styleScanTitle;

  /// No description provided for @takePhoto.
  ///
  /// In id, this message translates to:
  /// **'Ambil Foto'**
  String get takePhoto;

  /// No description provided for @uploadImage.
  ///
  /// In id, this message translates to:
  /// **'Unggah Gambar'**
  String get uploadImage;

  /// No description provided for @scanResultTitle.
  ///
  /// In id, this message translates to:
  /// **'Hasil Scan Gaya'**
  String get scanResultTitle;

  /// No description provided for @aiAnalysis.
  ///
  /// In id, this message translates to:
  /// **'Analisis AI:'**
  String get aiAnalysis;

  /// No description provided for @detectedStyle.
  ///
  /// In id, this message translates to:
  /// **'Gaya Terdeteksi:'**
  String get detectedStyle;

  /// No description provided for @confidence.
  ///
  /// In id, this message translates to:
  /// **'Kecocokan:'**
  String get confidence;

  /// No description provided for @faceShape.
  ///
  /// In id, this message translates to:
  /// **'Bentuk Wajah:'**
  String get faceShape;

  /// No description provided for @descriptionLabel.
  ///
  /// In id, this message translates to:
  /// **'Deskripsi:'**
  String get descriptionLabel;

  /// No description provided for @bookWithThisStyle.
  ///
  /// In id, this message translates to:
  /// **'Book Barbershop dengan Gaya Ini'**
  String get bookWithThisStyle;

  /// No description provided for @rescan.
  ///
  /// In id, this message translates to:
  /// **'Scan Ulang / Ambil Gambar Baru'**
  String get rescan;

  /// No description provided for @errScanFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal scan: {error}'**
  String errScanFailed(String error);

  /// No description provided for @cameraAccessDenied.
  ///
  /// In id, this message translates to:
  /// **'Akses Kamera ditolak.'**
  String get cameraAccessDenied;

  /// No description provided for @galleryAccessDenied.
  ///
  /// In id, this message translates to:
  /// **'Akses Galeri ditolak.'**
  String get galleryAccessDenied;

  /// No description provided for @chatTitle.
  ///
  /// In id, this message translates to:
  /// **'GIA - GEGES Intelligent Assistant'**
  String get chatTitle;

  /// No description provided for @giaGreeting.
  ///
  /// In id, this message translates to:
  /// **'Halo! Saya GIA, asisten virtual GEGES. Ada yang bisa saya bantu?'**
  String get giaGreeting;

  /// No description provided for @errMustLoginChat.
  ///
  /// In id, this message translates to:
  /// **'Silakan login terlebih dahulu untuk mengecek antrian.'**
  String get errMustLoginChat;

  /// No description provided for @noActiveBookings.
  ///
  /// In id, this message translates to:
  /// **'Anda belum memiliki booking aktif saat ini. Yuk buat booking baru!'**
  String get noActiveBookings;

  /// No description provided for @activeBookingDesc.
  ///
  /// In id, this message translates to:
  /// **'Booking aktif Anda:\n📅 {date}\n🔖 Status: {status}\n📍 Barbershop ID: {shopId}'**
  String activeBookingDesc(String date, String status, String shopId);

  /// No description provided for @errCheckQueueFailed.
  ///
  /// In id, this message translates to:
  /// **'Maaf, saya gagal mengecek data antrian Anda. Coba lagi nanti.'**
  String get errCheckQueueFailed;

  /// No description provided for @errNoStylesAvailable.
  ///
  /// In id, this message translates to:
  /// **'Maaf, data gaya rambut sedang tidak tersedia.'**
  String get errNoStylesAvailable;

  /// No description provided for @popularServicesHeader.
  ///
  /// In id, this message translates to:
  /// **'Berikut beberapa layanan populer kami:'**
  String get popularServicesHeader;

  /// No description provided for @errLoadRecommendationFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat rekomendasi.'**
  String get errLoadRecommendationFailed;

  /// No description provided for @branchInfo.
  ///
  /// In id, this message translates to:
  /// **'Kami memiliki banyak cabang! Gunakan fitur \'Lokasi Saya\' di halaman Home untuk menemukan yang terdekat.'**
  String get branchInfo;

  /// No description provided for @giaFallback.
  ///
  /// In id, this message translates to:
  /// **'Maaf, saya belum mengerti. Coba kata kunci: \'antrian saya\', \'rekomendasi gaya\', atau \'alamat\'.'**
  String get giaFallback;

  /// No description provided for @giaTyping.
  ///
  /// In id, this message translates to:
  /// **'GIA sedang mengetik...'**
  String get giaTyping;

  /// No description provided for @chatMinutes.
  ///
  /// In id, this message translates to:
  /// **'menit'**
  String get chatMinutes;

  /// No description provided for @seeDetail.
  ///
  /// In id, this message translates to:
  /// **'Lihat Detail'**
  String get seeDetail;

  /// No description provided for @btnCheckMyQueue.
  ///
  /// In id, this message translates to:
  /// **'Cek antrian saya'**
  String get btnCheckMyQueue;

  /// No description provided for @btnHaircutRecommendation.
  ///
  /// In id, this message translates to:
  /// **'Rekomendasi gaya rambut'**
  String get btnHaircutRecommendation;

  /// No description provided for @btnAskAddress.
  ///
  /// In id, this message translates to:
  /// **'Tanyakan alamat'**
  String get btnAskAddress;

  /// No description provided for @btnCreateNewBooking.
  ///
  /// In id, this message translates to:
  /// **'Buat Booking Baru'**
  String get btnCreateNewBooking;

  /// No description provided for @chatHint.
  ///
  /// In id, this message translates to:
  /// **'Tulis pesan...'**
  String get chatHint;

  /// No description provided for @stepService.
  ///
  /// In id, this message translates to:
  /// **'Layanan'**
  String get stepService;

  /// No description provided for @stepBarber.
  ///
  /// In id, this message translates to:
  /// **'Barber'**
  String get stepBarber;

  /// No description provided for @stepSchedule.
  ///
  /// In id, this message translates to:
  /// **'Jadwal'**
  String get stepSchedule;

  /// No description provided for @selectServiceTitle.
  ///
  /// In id, this message translates to:
  /// **'Pilih Layanan'**
  String get selectServiceTitle;

  /// No description provided for @selectServiceSubtitle.
  ///
  /// In id, this message translates to:
  /// **'Anda bisa memilih lebih dari satu layanan'**
  String get selectServiceSubtitle;

  /// No description provided for @whoCutsTitle.
  ///
  /// In id, this message translates to:
  /// **'Siapa yang mencukur?'**
  String get whoCutsTitle;

  /// No description provided for @barberChoiceSystem.
  ///
  /// In id, this message translates to:
  /// **'Dipilihkan Sistem (Adil & Cepat)'**
  String get barberChoiceSystem;

  /// No description provided for @barberChoiceSystemDesc.
  ///
  /// In id, this message translates to:
  /// **'Sistem akan mencarikan barber terbaik yang tersedia untuk Anda.'**
  String get barberChoiceSystemDesc;

  /// No description provided for @barberChoiceFavorite.
  ///
  /// In id, this message translates to:
  /// **'Pilih Barber Favorit'**
  String get barberChoiceFavorite;

  /// No description provided for @barberChoiceFavoriteDesc.
  ///
  /// In id, this message translates to:
  /// **'Pilih barber tertentu yang sudah Anda kenal (+ Rp {fee})'**
  String barberChoiceFavoriteDesc(String fee);

  /// No description provided for @specialistList.
  ///
  /// In id, this message translates to:
  /// **'Daftar Specialist'**
  String get specialistList;

  /// No description provided for @scheduleTitle.
  ///
  /// In id, this message translates to:
  /// **'Tentukan Jadwal'**
  String get scheduleTitle;

  /// No description provided for @pickDay.
  ///
  /// In id, this message translates to:
  /// **'Pilih Hari'**
  String get pickDay;

  /// No description provided for @pickTime.
  ///
  /// In id, this message translates to:
  /// **'Pilih Jam'**
  String get pickTime;

  /// No description provided for @shopHoliday.
  ///
  /// In id, this message translates to:
  /// **'LIBUR'**
  String get shopHoliday;

  /// No description provided for @totalEst.
  ///
  /// In id, this message translates to:
  /// **'Total Estimasi'**
  String get totalEst;

  /// No description provided for @btnNext.
  ///
  /// In id, this message translates to:
  /// **'LANJUT'**
  String get btnNext;

  /// No description provided for @btnBookNow.
  ///
  /// In id, this message translates to:
  /// **'BOOK NOW'**
  String get btnBookNow;

  /// No description provided for @confirmBookingTitle.
  ///
  /// In id, this message translates to:
  /// **'Konfirmasi Booking'**
  String get confirmBookingTitle;

  /// No description provided for @labelDate.
  ///
  /// In id, this message translates to:
  /// **'Tanggal'**
  String get labelDate;

  /// No description provided for @labelTime.
  ///
  /// In id, this message translates to:
  /// **'Jam'**
  String get labelTime;

  /// No description provided for @labelBarber.
  ///
  /// In id, this message translates to:
  /// **'Barber'**
  String get labelBarber;

  /// No description provided for @labelTotalCost.
  ///
  /// In id, this message translates to:
  /// **'Total Biaya'**
  String get labelTotalCost;

  /// No description provided for @btnCancel.
  ///
  /// In id, this message translates to:
  /// **'Batal'**
  String get btnCancel;

  /// No description provided for @btnConfirmBook.
  ///
  /// In id, this message translates to:
  /// **'Booking Sekarang'**
  String get btnConfirmBook;

  /// No description provided for @errPickService.
  ///
  /// In id, this message translates to:
  /// **'Pilih minimal satu layanan'**
  String get errPickService;

  /// No description provided for @errPickBarber.
  ///
  /// In id, this message translates to:
  /// **'Silakan pilih barber favorit Anda'**
  String get errPickBarber;

  /// No description provided for @errPickBarberFirst.
  ///
  /// In id, this message translates to:
  /// **'Pilih barber terlebih dahulu'**
  String get errPickBarberFirst;

  /// No description provided for @errBarberBusy.
  ///
  /// In id, this message translates to:
  /// **'Barber tersebut sudah ada jadwal di jam ini'**
  String get errBarberBusy;

  /// No description provided for @errNoFairBarber.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada hairstylist tersedia jam ini. Coba jam lain.'**
  String get errNoFairBarber;

  /// No description provided for @errShopClosed.
  ///
  /// In id, this message translates to:
  /// **'{shopName} Sedang Tutup'**
  String errShopClosed(String shopName);

  /// No description provided for @errShopClosedDesc.
  ///
  /// In id, this message translates to:
  /// **'Maaf, barbershop ini sedang tidak menerima pesanan.\nSilakan cek kembali nanti.'**
  String get errShopClosedDesc;

  /// No description provided for @barberOffDay.
  ///
  /// In id, this message translates to:
  /// **'{name} libur pada tanggal ini.'**
  String barberOffDay(String name);

  /// No description provided for @barberOffDayDesc.
  ///
  /// In id, this message translates to:
  /// **'Silakan pilih tanggal lain atau barber lain.'**
  String get barberOffDayDesc;

  /// No description provided for @randomSystem.
  ///
  /// In id, this message translates to:
  /// **'Sistem Acak'**
  String get randomSystem;

  /// No description provided for @myOrders.
  ///
  /// In id, this message translates to:
  /// **'Pesanan Saya'**
  String get myOrders;

  /// No description provided for @tabUnpaid.
  ///
  /// In id, this message translates to:
  /// **'Belum Bayar'**
  String get tabUnpaid;

  /// No description provided for @tabScheduled.
  ///
  /// In id, this message translates to:
  /// **'Terjadwal'**
  String get tabScheduled;

  /// No description provided for @tabProcessing.
  ///
  /// In id, this message translates to:
  /// **'Sedang Proses'**
  String get tabProcessing;

  /// No description provided for @tabCompleted.
  ///
  /// In id, this message translates to:
  /// **'Selesai'**
  String get tabCompleted;

  /// No description provided for @tabCancelled.
  ///
  /// In id, this message translates to:
  /// **'Dibatalkan'**
  String get tabCancelled;

  /// No description provided for @loginRequired.
  ///
  /// In id, this message translates to:
  /// **'Wajib login'**
  String get loginRequired;

  /// No description provided for @noOrders.
  ///
  /// In id, this message translates to:
  /// **'Tidak ada pesanan'**
  String get noOrders;

  /// No description provided for @statusUnpaid.
  ///
  /// In id, this message translates to:
  /// **'BELUM BAYAR'**
  String get statusUnpaid;

  /// No description provided for @statusCancelled.
  ///
  /// In id, this message translates to:
  /// **'DIBATALKAN'**
  String get statusCancelled;

  /// No description provided for @statusCancelRequested.
  ///
  /// In id, this message translates to:
  /// **'PERMOHONAN PEMBATALAN'**
  String get statusCancelRequested;

  /// No description provided for @statusCompleted.
  ///
  /// In id, this message translates to:
  /// **'SELESAI'**
  String get statusCompleted;

  /// No description provided for @statusProcessing.
  ///
  /// In id, this message translates to:
  /// **'SEDANG DIPROSES'**
  String get statusProcessing;

  /// No description provided for @statusScheduled.
  ///
  /// In id, this message translates to:
  /// **'TERJADWAL'**
  String get statusScheduled;

  /// No description provided for @statusPendingVerification.
  ///
  /// In id, this message translates to:
  /// **'MENUNGGU VERIFIKASI'**
  String get statusPendingVerification;

  /// No description provided for @specialOrders.
  ///
  /// In id, this message translates to:
  /// **'Pesanan Khusus'**
  String get specialOrders;

  /// No description provided for @pleaseLoginFirst.
  ///
  /// In id, this message translates to:
  /// **'Silakan login terlebih dahulu'**
  String get pleaseLoginFirst;

  /// No description provided for @errLoadingOrders.
  ///
  /// In id, this message translates to:
  /// **'Gagal memuat pesanan: {error}'**
  String errLoadingOrders(String error);

  /// No description provided for @noSpecialOrders.
  ///
  /// In id, this message translates to:
  /// **'Belum ada Pesanan Khusus'**
  String get noSpecialOrders;

  /// No description provided for @statusAwaitingPayment.
  ///
  /// In id, this message translates to:
  /// **'Menunggu Pembayaran'**
  String get statusAwaitingPayment;

  /// No description provided for @descAwaitingPayment.
  ///
  /// In id, this message translates to:
  /// **'Selesaikan pembayaran untuk memproses pendaftaran.'**
  String get descAwaitingPayment;

  /// No description provided for @statusActivePartnership.
  ///
  /// In id, this message translates to:
  /// **'SUKSES / AKTIF'**
  String get statusActivePartnership;

  /// No description provided for @descActivePartnership.
  ///
  /// In id, this message translates to:
  /// **'Selamat! Partnership Anda telah aktif.'**
  String get descActivePartnership;

  /// No description provided for @statusCancelledRejected.
  ///
  /// In id, this message translates to:
  /// **'DIBATALKAN / DITOLAK'**
  String get statusCancelledRejected;

  /// No description provided for @descCancelledRejected.
  ///
  /// In id, this message translates to:
  /// **'Permintaan ini tidak dapat diproses.'**
  String get descCancelledRejected;

  /// No description provided for @statusWaitingVerification.
  ///
  /// In id, this message translates to:
  /// **'MENUNGGU VERIFIKASI'**
  String get statusWaitingVerification;

  /// No description provided for @descWaitingVerification.
  ///
  /// In id, this message translates to:
  /// **'Bukti diterima. Admin sedang memverifikasi data Anda.'**
  String get descWaitingVerification;

  /// No description provided for @btnResumePayment.
  ///
  /// In id, this message translates to:
  /// **'LANJUTKAN PEMBAYARAN'**
  String get btnResumePayment;

  /// No description provided for @registrationIncompleteTitle.
  ///
  /// In id, this message translates to:
  /// **'Pendaftaran Belum Selesai'**
  String get registrationIncompleteTitle;

  /// No description provided for @registrationIncompleteMsg.
  ///
  /// In id, this message translates to:
  /// **'Anda belum mengunggah bukti pembayaran. Data pendaftaran Anda tersimpan sebagai \'Menunggu Pembayaran\' dan bisa dilanjutkan nanti.'**
  String get registrationIncompleteMsg;

  /// No description provided for @btnCancelExit.
  ///
  /// In id, this message translates to:
  /// **'Batal Keluar'**
  String get btnCancelExit;

  /// No description provided for @btnExitSaveDraft.
  ///
  /// In id, this message translates to:
  /// **'Keluar (Simpan Draft)'**
  String get btnExitSaveDraft;

  /// No description provided for @btnCancelRegistration.
  ///
  /// In id, this message translates to:
  /// **'Batalkan Pendaftaran'**
  String get btnCancelRegistration;

  /// No description provided for @registrationDetail.
  ///
  /// In id, this message translates to:
  /// **'Detail Pendaftaran'**
  String get registrationDetail;

  /// No description provided for @cancelRegistrationTitle.
  ///
  /// In id, this message translates to:
  /// **'Batalkan Pendaftaran?'**
  String get cancelRegistrationTitle;

  /// No description provided for @cancelRegistrationWarning.
  ///
  /// In id, this message translates to:
  /// **'Jika Anda membatalkan pendaftaran yang SUDAH DIBAYAR, dana akan dikembalikan dengan POTONGAN 10% (biaya admin).\n\nApakah Anda yakin?'**
  String get cancelRegistrationWarning;

  /// No description provided for @btnBack.
  ///
  /// In id, this message translates to:
  /// **'Kembali'**
  String get btnBack;

  /// No description provided for @btnYesCancel.
  ///
  /// In id, this message translates to:
  /// **'Ya, Batalkan'**
  String get btnYesCancel;

  /// No description provided for @msgCancelSent.
  ///
  /// In id, this message translates to:
  /// **'Permintaan pembatalan dikirim.'**
  String get msgCancelSent;

  /// No description provided for @errCancelFailed.
  ///
  /// In id, this message translates to:
  /// **'Gagal membatalkan: {error}'**
  String errCancelFailed(String error);

  /// No description provided for @errOpenWhatsApp.
  ///
  /// In id, this message translates to:
  /// **'Gagal membuka WhatsApp support'**
  String get errOpenWhatsApp;

  /// No description provided for @statusActiveCompleted.
  ///
  /// In id, this message translates to:
  /// **'AKTIF / SELESAI'**
  String get statusActiveCompleted;

  /// No description provided for @statusRefundProcessing.
  ///
  /// In id, this message translates to:
  /// **'REFUND DIPROSES'**
  String get statusRefundProcessing;

  /// No description provided for @businessInfo.
  ///
  /// In id, this message translates to:
  /// **'Informasi Bisnis'**
  String get businessInfo;

  /// No description provided for @barbershopName.
  ///
  /// In id, this message translates to:
  /// **'Nama Barbershop'**
  String get barbershopName;

  /// No description provided for @subscriptionPlan.
  ///
  /// In id, this message translates to:
  /// **'Paket Langganan'**
  String get subscriptionPlan;

  /// No description provided for @registrationFee.
  ///
  /// In id, this message translates to:
  /// **'Biaya Pendaftaran'**
  String get registrationFee;

  /// No description provided for @address.
  ///
  /// In id, this message translates to:
  /// **'Alamat'**
  String get address;

  /// No description provided for @adminAccountTitle.
  ///
  /// In id, this message translates to:
  /// **'Akun Admin Barbershop'**
  String get adminAccountTitle;

  /// No description provided for @adminAccountDesc.
  ///
  /// In id, this message translates to:
  /// **'Gunakan akun ini untuk login ke Aplikasi Admin:'**
  String get adminAccountDesc;

  /// No description provided for @btnLogoutLoginAdmin.
  ///
  /// In id, this message translates to:
  /// **'LOGOUT & LOGIN SEBAGAI ADMIN'**
  String get btnLogoutLoginAdmin;

  /// No description provided for @contactAdmin.
  ///
  /// In id, this message translates to:
  /// **'Hubungi Admin'**
  String get contactAdmin;

  /// No description provided for @loginAsAdminTitle.
  ///
  /// In id, this message translates to:
  /// **'Login sebagai Admin?'**
  String get loginAsAdminTitle;

  /// No description provided for @loginAsAdminMsg.
  ///
  /// In id, this message translates to:
  /// **'Anda akan keluar dari akun Customer ini.\n\nSilakan gunakan Email & Password yang tertera di atas untuk login kembali sebagai Owner Barbershop.'**
  String get loginAsAdminMsg;

  /// No description provided for @btnYesLogout.
  ///
  /// In id, this message translates to:
  /// **'Ya, Logout'**
  String get btnYesLogout;

  /// No description provided for @cancelDetail.
  ///
  /// In id, this message translates to:
  /// **'Detail Pembatalan'**
  String get cancelDetail;

  /// No description provided for @reason.
  ///
  /// In id, this message translates to:
  /// **'Alasan'**
  String get reason;

  /// No description provided for @viewRefundProof.
  ///
  /// In id, this message translates to:
  /// **'Lihat Bukti Refund'**
  String get viewRefundProof;

  /// No description provided for @btnPayNow.
  ///
  /// In id, this message translates to:
  /// **'BAYAR SEKARANG'**
  String get btnPayNow;

  /// No description provided for @contactSupport.
  ///
  /// In id, this message translates to:
  /// **'Hubungi Bantuan / Komplain'**
  String get contactSupport;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
