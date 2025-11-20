// ==========================================
// file: lib/screens/register_screen.dart
// deskripsi: layar registrasi untuk membuat akun baru
// penjelasan:
//   - user memasukkan nama, email, password & confirm password
//   - ada validasi form (email format, password strength, matching)
//   - ada tombol google sign-up (placeholder)
//   - setelah register sukses, navigasi ke login screen
//   - dibuat akun di firebase auth & user document di firestore
// ==========================================

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';

// penjelasan statefulwidget:
// - registerscreen adalah statefulwidget karena ada state yang berubah (error message, loading)
// - setstate() dipanggil untuk update ui saat ada perubahan
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // penjelasan controller:
  // - textEditingController digunakan untuk menangkap text yang user ketik di TextField
  // - _nameController untuk menangkap input nama
  // - _emailController untuk menangkap input email
  // - _passwordController untuk menangkap input password
  // - _confirmPasswordController untuk menangkap konfirmasi password
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // penjelasan firebase instances:
  // - firebaseauth digunakan untuk operasi auth (create user account)
  // - firebasefirestore digunakan untuk menyimpan user document di cloud firestore
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // penjelasan variabel state:
  // - _errorMessage: menampilkan pesan error jika registrasi gagal
  // - _isLoading: flag untuk menampilkan loading spinner saat proses registrasi
  String _errorMessage = '';
  bool _isLoading = false;

  // penjelasan warna tema:
  // - kBrownAccent: warna coklat utama dari design system
  // - kDarkGrey: warna background untuk input field
  // - kHintText: warna teks hint/placeholder
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kHintText = Color(0xFF6B6B6B);

  // ========================================
  // fungsi registrasi dengan firebase auth & firestore
  // ========================================
  Future<void> _register() async {
    // penjelasan:
    // - fungsi ini dijalankan saat user tekan tombol "create account"
    // - mengambil nilai nama, email, password & confirm password dari controller
    // - validasi form (jangan kosong, password match, password min 6 char)
    // - buat akun firebase auth dengan email & password
    // - update display name di auth
    // - buat user document di firestore
    // - kirim email verifikasi
    // - jika sukses, navigasi ke login screen
    // - jika gagal, tampilkan error message
    
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    // penjelasan validasi input:
    // - cek apakah ada field yang kosong
    // - jika ada, tampilkan error message & return
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'semua field wajib diisi.');
      return;
    }
    
    // penjelasan validasi password match:
    // - cek apakah password dan konfirmasi sama
    // - jika tidak cocok, tampilkan error message
    if (password != confirm) {
      setState(() => _errorMessage = 'password dan konfirmasi tidak cocok.');
      return;
    }
    
    // penjelasan validasi password strength:
    // - cek apakah password minimal 6 karakter
    // - ini adalah minimal requirement dari firebase
    if (password.length < 6) {
      setState(() => _errorMessage = 'password minimal 6 karakter.');
      return;
    }

    // penjelasan setstate loading:
    // - ubah state _isLoading = true untuk menampilkan spinner
    // - kosongkan _errorMessage untuk menghapus pesan error sebelumnya
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // penjelasan step 1: create firebase auth account:
      // - firebaseauth.createUserWithEmailAndPassword() membuat akun baru
      // - mengembalikan usercredential yang berisi user instance
      // - jika email sudah terdaftar atau invalid, akan throw exception
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // penjelasan null check:
      // - user bisa null jika ada masalah (jarang terjadi)
      // - throw exception jika user null untuk trigger catch block
      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'null-user', message: 'gagal membuat akun.');
      }

      // penjelasan step 2: update display name di firebase auth:
      // - updateDisplayName() mengupdate nama user di firebase auth
      // - ini opsional tapi berguna untuk menampilkan nama user di tempat lain
      await user.updateDisplayName(name);
      
      // penjelasan step 3: buat user document di firestore:
      // - firestore.collection('users').doc(user.uid).set() membuat document baru
      // - menyimpan data user: uid, nama, email, role, created_at
      // - role default 'customer' untuk user baru yang register
      // - fieldvalue.servereimestamp() menggunakan server time untuk konsistensi data
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      // penjelasan step 4: kirim email verifikasi:
      // - sendemailverification() mengirim email ke user untuk verify email
      // - user harus verify email sebelum bisa menggunakan beberapa fitur
      // - link verifikasi valid selama beberapa jam
      await user.sendEmailVerification();

      // penjelasan mounted check:
      // - mounted adalah flag yang true jika widget masih di layar
      // - jika user navigate away sebelum register selesai, mounted akan false
      // - ini untuk mencegah error "setstate() called on unmounted widget"
      if (!mounted) return;
      
      // penjelasan step 5: tampilkan pesan sukses:
      // - snackbar untuk notifikasi sukses registrasi
      // - teks berisi email tujuan verifikasi
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('pendaftaran sukses! verifikasi email telah dikirim ke $email'),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      // penjelasan step 6: navigasi ke login:
      // - setelah registrasi sukses, navigasi ke login screen
      // - user bisa login dengan email & password yang baru dibuat
      _goToLogin();
    } on FirebaseAuthException catch (e) {
      // penjelasan error handling firebase auth:
      // - error dari firebase auth memiliki code yang spesifik
      // - berbeda kode error memberikan pesan yang berbeda
      // - "email-already-in-use": email sudah terdaftar akun lain
      // - "invalid-email": format email tidak valid
      // - "weak-password": password terlalu lemah (kurang 6 char)
      
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'email sudah terdaftar. gunakan email lain.';
          break;
        case 'invalid-email':
          msg = 'format email tidak valid.';
          break;
        case 'weak-password':
          msg = 'password terlalu lemah.';
          break;
        default:
          msg = e.message ?? 'terjadi kesalahan saat registrasi.';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      // penjelasan error handling umum:
      // - tangkap error lainnya seperti network error, firestore error, dll
      // - tampilkan pesan error yang user-friendly
      setState(() => _errorMessage = 'terjadi kesalahan: $e');
    } finally {
      // penjelasan finally block:
      // - finally block selalu dijalankan baik success atau error
      // - hidden loading spinner di sini
      // - mounted check untuk mencegah error
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ========================================
  // navigasi ke login screen
  // ========================================
  void _goToLogin() {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan tombol "log in" atau setelah register sukses
    // - navigasi ke loginscreen dengan pushReplacement (ganti screen, jangan push)
    // - transitionduration zero untuk instant transition tanpa animasi
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  // ========================================
  // google sign-up (placeholder)
  // ========================================
  void _signInWithGoogle() {
    // penjelasan:
    // - fungsi ini adalah placeholder untuk google sign-up
    // - di implementasi sebenarnya harus panggil authservice.signinwithgoogle()
    // - untuk saat ini hanya tampilkan snackbar bahwa fitur belum tersedia
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('fitur "sign in with google" belum diimplementasikan.')),
    );
  }

  // Helper function to check password strength
  String _getPasswordStrength(String password) {
    if (password.length < 6) return 'Lemah';
    final hasUpper = password.contains(RegExp(r'[A-Z]'));
    final hasLower = password.contains(RegExp(r'[a-z]'));
    final hasDigit = password.contains(RegExp(r'[0-9]'));
    final hasSpecial = password.contains(RegExp(r'[!@#\$%^&*(),.?":{}|<>]'));
    int score = [hasUpper, hasLower, hasDigit, hasSpecial].where((b) => b).length;
    if (score <= 2) return 'Sedang';
    if (score >= 3) return 'Kuat';
    return 'Lemah';
  }

  @override
  Widget build(BuildContext context) {
    // penjelasan build():
    // - method ini menampilkan ui layar register
    // - scaffold = layout dasar dengan appbar, body, dll
    // - singlechildscrollview = membuat content bisa di-scroll jika terlalu panjang
    // - column = tata letak vertikal (dari atas ke bawah)
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        // penjelasan safarea:
        // - safarea memastikan content tidak overlap dengan status bar atau notch
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // penjelasan logo:
              // - image.asset memuat gambar dari folder assets
              // - height 120 untuk mengatur ukuran logo
              // - errorbuilder menampilkan icon jika gambar tidak ditemukan
              Image.asset(
                'assets/images/ivon.png',
                height: 120,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.cut, color: kBrownAccent, size: 120),
              ),
              const SizedBox(height: 24),
              
              // penjelasan judul & subtitle:
              // - text untuk menampilkan teks statis
              // - textalign center untuk meratakan ke tengah
              // - fontsize & fontweight untuk mengatur ukuran & tebal
              const Text(
                'Welcome to GEGES',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              // subtitle
              const Text(
                'Sign in or create an account to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              
              // penjelasan tab login/signup:
              // - _buildAuthTabs() adalah custom widget untuk tombol tab login/signup
              // - isLogin false karena ini halaman signup
              // - onLoginTap callback dipanggil saat user tekan tab "log in"
              _buildAuthTabs(isLogin: false, onLoginTap: _goToLogin),
              const SizedBox(height: 32),

              // penjelasan input fields:
              // - 4 text fields untuk nama, email, password, confirm password
              // - _buildTextField() adalah custom widget untuk input field styling
              // - hinttext, icon, keyboardtype parameter untuk konfigurasi
              // username field
              _buildTextField(_nameController, 'Username', Icons.person_outline),
              const SizedBox(height: 16),
              // email field
              _buildTextField(_emailController, 'Email', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              // password field (hidden)
              _buildTextField(_passwordController, 'Password', Icons.lock_outline, isObscure: true),
              const SizedBox(height: 16),
              // confirm password field (hidden)
              _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline,
                  isObscure: true),
              const SizedBox(height: 20),

              // penjelasan password strength indicator:
              // - ditampilkan di bawah password field
              // - menunjukkan kekuatan password: lemah/sedang/kuat
              // - warna hijau/orange/merah sesuai dengan tingkat kekuatan
              Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                child: Text(
                  'Kekuatan Password: ${_getPasswordStrength(_passwordController.text)}',
                  style: TextStyle(
                    color: _getPasswordStrength(_passwordController.text) == 'Kuat'
                        ? Colors.green
                        : (_getPasswordStrength(_passwordController.text) == 'Sedang' ? Colors.orange : Colors.red),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),

              // penjelasan error message:
              // - hanya ditampilkan jika _errorMessage tidak kosong
              // - padding untuk spacing
              // - text style warna merah untuk error
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),

              // penjelasan create account button:
              // - sizedbox height 55 untuk mengatur tinggi tombol
              // - jika _isLoading true, tampilkan spinner
              // - jika false, tampilkan elevatedbutton dengan label "create account"
              // - onpressed memanggil _register()
              SizedBox(
                height: 55,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
                    : ElevatedButton(
                        onPressed: _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kBrownAccent,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Create Account',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
              ),
              const SizedBox(height: 32),

              // penjelasan separator:
              // - baris dengan garis di kanan-kiri dengan "or" di tengah
              // - row dengan expanded untuk membuat garis responsive
              _buildSeparator(),
              const SizedBox(height: 32),

              // penjelasan google sign-up button:
              // - elevatedbutton.icon untuk tombol dengan icon & text
              // - image.asset memuat google logo
              // - onpressed memanggil _signInWithGoogle()
              SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: Image.asset(
                    'assets/images/google.png',
                    height: 24,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.android, color: Colors.white, size: 24),
                  ),
                  label: const Text('Continue with Google', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kDarkGrey,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade800),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
              
              // penjelasan footer terms:
              // - richtext untuk membuat text dengan style berbeda di bagian yang berbeda
              // - textspan untuk mendefinisikan style per bagian
              // - tapgesturerecognizer untuk membuat teks clickable
              _buildFooterTerms(),
            ],
          ),
        ),
      ),
    );
  }

  // ========================================
  // custom widget: tab untuk login/signup
  // ========================================
  Widget _buildAuthTabs({required bool isLogin, required VoidCallback onLoginTap}) {
    // penjelasan:
    // - widget ini menampilkan 2 tab: "log in" dan "sign up"
    // - tab yang aktif memiliki background coklat
    // - tab yang tidak aktif transparan
    // - ontap callback dipanggil saat user tekan tab
    
    return Container(
      decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          // penjelasan tab login:
          // - gesturedetector untuk mendeteksi tap
          // - ontap callback untuk navigasi ke login screen
          // - container dengan background coklat jika aktif (islogin true)
          Expanded(
            child: GestureDetector(
              onTap: onLoginTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                    color: isLogin ? kBrownAccent : Colors.transparent,
                    borderRadius: BorderRadius.circular(12)),
                child: Text('Log in',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: isLogin ? Colors.black : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
              ),
            ),
          ),
          // penjelasan tab signup:
          // - expanded membuat tab mengambil ruang sama rata
          // - container dengan background coklat untuk tab signup (aktif)
          // - text "sign up" dengan alignment center
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                  color: !isLogin ? kBrownAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(12)),
              child: const Text('Sign Up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // custom widget: text input field
  // ========================================
  Widget _buildTextField(TextEditingController c, String hint, IconData icon,
      {bool isObscure = false, TextInputType keyboardType = TextInputType.text}) {
    // penjelasan:
    // - reusable widget untuk membuat input field dengan style yang konsisten
    // - c: controller menangkap text yang user ketik
    // - hint: placeholder text saat field kosong
    // - icon: icon di sebelah kiri input
    // - isobscure: true untuk password field (hide character)
    // - keyboardtype: tipe keyboard yang muncul (email, number, text, dll)
    
    return TextField(
      controller: c,
      obscureText: isObscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kHintText),
        filled: true,
        fillColor: kDarkGrey,
        prefixIcon: Icon(icon, color: kHintText, size: 22),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
        ),
      ),
    );
  }

  // ========================================
  // custom widget: separator dengan "or" text
  // ========================================
  Widget _buildSeparator() {
    // penjelasan:
    // - widget ini menampilkan baris dengan garis di kanan-kiri dengan "or" di tengah
    // - divider untuk membuat garis horizontal
    // - row dengan expanded untuk membuat garis responsive
    
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade800)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text('or', style: TextStyle(color: Colors.white70)),
        ),
        Expanded(child: Divider(color: Colors.grey.shade800)),
      ],
    );
  }

  // ========================================
  // custom widget: footer dengan terms & privacy policy
  // ========================================
  Widget _buildFooterTerms() {
    // penjelasan:
    // - richtext untuk membuat text dengan style berbeda di bagian yang berbeda
    // - textspan untuk mendefinisikan style per bagian
    // - tapgesturerecognizer untuk membuat teks clickable
    
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        children: [
          const TextSpan(text: 'By continuing, you agree to our\n'),
          TextSpan(
              text: 'Terms of Services',
              style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () {
                // TODO: buka halaman terms of services
              }),
          const TextSpan(text: ' and '),
          TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () {
                // TODO: buka halaman privacy policy
              }),
        ],
      ),
    );
  }
}
