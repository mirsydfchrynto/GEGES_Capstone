// ==========================================
// file: lib/screens/login_screen.dart
// deskripsi: layar login untuk masuk ke aplikasi
// penjelasan:
//   - user memasukkan email & password
//   - ada tombol login biasa & google sign-in
//   - ada tombol forgot password untuk reset password
//   - setelah login berhasil, navigasi ke home (customer) atau admin dashboard
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/screens/admin/admin_dashboard.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';

// penjelasan statefulwidget:
// - loginscreen adalah statefulwidget karena ada state yang berubah (error message, loading, password visible)
// - setstate() dipanggil untuk update ui saat ada perubahan
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // penjelasan controller:
  // - textEditingController digunakan untuk menangkap text yang user ketik di TextField
  // - _emailController untuk menangkap input email
  // - _passwordController untuk menangkap input password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // penjelasan authservice:
  // - authservice adalah service yang menangani semua operasi autentikasi (login, register, google sign-in)
  // - sudah diimplementasikan di lib/services/auth_service.dart
  final AuthService _authService = AuthService();

  // penjelasan variabel state:
  // - _errorMessage: menampilkan pesan error jika login gagal (email tidak terdaftar, password salah, dll)
  // - _isLoading: flag untuk menampilkan loading spinner saat proses login sedang berjalan
  // - _obscurePassword: flag untuk menyembunyikan/menampilkan password (tombol mata)
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // penjelasan warna tema:
  // - kBrownAccent: warna coklat utama dari design system
  // - kDarkGrey: warna background untuk input field
  // - kHintText: warna teks hint/placeholder
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kHintText = Color(0xFF6B6B6B);

  @override
  void dispose() {
    // penjelasan dispose:
    // - dispose() dipanggil saat widget dihancurkan
    // - penting untuk melepaskan resources seperti controller untuk mencegah memory leak
    // - harus selalu panggil super.dispose() di akhir
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ========================================
  // fungsi login dengan email & password
  // ========================================
  void _login() async {
    // penjelasan:
    // - fungsi ini dijalankan saat user tekan tombol "sign in"
    // - mengambil nilai email & password dari controller
    // - validasi input (jangan kosong)
    // - panggil authservice.signin() untuk authenticate ke firebase
    // - jika sukses, navigasi ke home atau admin dashboard berdasarkan role
    // - jika gagal, tampilkan error message
    
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    // penjelasan validasi:
    // - cek apakah email atau password kosong
    // - jika kosong, tampilkan error message & return (keluar dari fungsi)
    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'email dan password wajib diisi.');
      return;
    }

    // penjelasan setstate:
    // - ubah state _isLoading = true untuk menampilkan spinner
    // - kosongkan _errorMessage untuk menghapus pesan error sebelumnya
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // penjelasan async operation:
      // - panggil _authService.signIn() yang mengembalikan future dengan hasil
      // - result berisi {success: true/false, role: 'customer'/'admin_owner', message: 'error message'}
      final result = await _authService.signIn(email: email, password: password);

      // penjelasan mounted check:
      // - mounted adalah flag yang true jika widget masih di layar
      // - jika user navigate away sebelum login selesai, mounted akan false
      // - ini untuk mencegah error "setState() called on unmounted widget"
      if (!mounted) return;
      setState(() => _isLoading = false);

      // penjelasan kondisi login:
      // - jika result['success'] true, berarti login sukses
      // - navigasi ke home atau admin berdasarkan role
      // - jika gagal, simpan error message di _errorMessage untuk ditampilkan di UI
      if (result['success'] == true) {
        _navigateByRole(result['role']);
      } else {
        setState(() => _errorMessage = result['message'] ?? 'login gagal.');
      }
    } catch (e) {
      // penjelasan error handling:
      // - jika ada exception (network error, firebase error, dll), tangkap di sini
      // - tampilkan pesan error yang user-friendly
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'terjadi kesalahan: $e';
      });
    }
  }

  // ========================================
  // navigasi berdasarkan role user
  // ========================================
  void _navigateByRole(String? role) {
    // penjelasan:
    // - role bisa 'customer' atau 'admin_owner'
    // - jika customer, navigasi ke HomeScreen
    // - jika admin_owner, navigasi ke AdminDashboardScreen
    // - pushReplacement() berarti ganti layar ini dengan layar baru (jadi tidak bisa kembali ke login)
    
    Widget targetScreen;
    if (role == 'customer') {
      targetScreen = const HomeScreen();
    } else if (role == 'admin_owner') {
      targetScreen = const AdminDashboardScreen();
    } else {
      setState(() => _errorMessage = 'role pengguna tidak valid.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  // ========================================
  // navigasi ke register screen
  // ========================================
  void _goToRegister() {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan tombol "sign up"
    // - navigasi ke RegisterScreen dengan transisi 0 (instant, tidak ada animasi)
    // - kosongkan error message
    
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) => const RegisterScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    if (mounted) setState(() => _errorMessage = '');
  }

  // ========================================
  // forgot password: kirim link reset ke email
  // ========================================
  void _forgotPassword() async {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan "forgot password?"
    // - jika email field kosong, tanya email melalui dialog
    // - kirim link reset password ke email melalui firebase
    
    final email = _emailController.text.trim();

    // penjelasan kondisi:
    // - jika email kosong, tanyakan via dialog
    // - jika user cancel, tampilkan snackbar
    // - jika user input email, kirim reset email
    if (email.isEmpty) {
      final typed = await _askForEmailDialog();
      if (typed == null || typed.trim().isEmpty) {
  _showSnackbar('masukkan email untuk menerima link reset.', const Color(0xFFD32F2F));
        return;
      }
      await _sendResetEmail(typed.trim());
      return;
    }

    await _sendResetEmail(email);
  }

  // penjelasan fungsi helper:
  // - fungsi ini mengirim reset password email ke firebase
  // - tampilkan loading spinner selama proses
  // - setelah selesai, tampilkan snackbar sukses/gagal
  Future<void> _sendResetEmail(String email) async {
    setState(() => _isLoading = true);
    try {
      final res = await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _showSnackbar('link reset password telah dikirim ke $email.', kBrownAccent);
      } else {
  _showSnackbar(res['message'] ?? 'gagal mengirim link reset password.', const Color(0xFFD32F2F));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
  _showSnackbar('terjadi kesalahan: $e', const Color(0xFFD32F2F));
    }
  }

  // ========================================
  // google sign-in
  // ========================================
  void _signInWithGoogle() async {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan tombol "continue with google"
    // - panggil _authService.signInWithGoogle() untuk authenticate dengan google
    // - jika sukses, navigasi ke home atau admin berdasarkan role
    // - jika gagal, tampilkan error message
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _authService.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _navigateByRole(result['role']);
      } else {
        final message = result['message'] ?? 'google sign-in gagal.';
  _showSnackbar(message, const Color(0xFFD32F2F));
        setState(() => _errorMessage = message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'terjadi kesalahan: $e';
      });
  _showSnackbar('terjadi kesalahan: $e', const Color(0xFFD32F2F));
    }
  }

  // ========================================
  // dialog: tanya email untuk reset password
  // ========================================
  Future<String?> _askForEmailDialog() async {
    // penjelasan:
    // - dialog ini muncul saat user tekan "forgot password?" tanpa input email
    // - user bisa input email & tekan "kirim" atau tekan "batal"
    // - mengembalikan email yang diinput atau null jika dibatalkan
    
    String typed = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('reset password', style: TextStyle(color: Colors.white)),
          content: TextField(
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'masukkan email anda'),
            onChanged: (v) => typed = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
              onPressed: () => Navigator.of(context).pop(typed),
              child: const Text('kirim'),
            ),
          ],
        );
      },
    );
  }

  // ========================================
  // helper: tampilkan snackbar di bawah layar
  // ========================================
  void _showSnackbar(String msg, Color color) {
    // penjelasan:
    // - snackbar adalah notifikasi yang muncul di bawah layar
    // - mounted check untuk memastikan widget masih ada di memory
    // - backgroundColor color untuk warna snackbar (hijau sukses, merah error)
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset(
                  'assets/images/ivon.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.cut, color: kBrownAccent, size: 120),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to GEGES',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Sign in or create an account to get started.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                _buildAuthTabs(isLogin: true, onSignUpTap: _goToRegister),
                const SizedBox(height: 32),

                // Email
                _buildTextField(
                  controller: _emailController,
                  hintText: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),

                // Password with toggle
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Password',
                    hintStyle: const TextStyle(color: kHintText),
                    filled: true,
                    fillColor: kDarkGrey,
                    prefixIcon: const Icon(Icons.lock_outline, color: kHintText, size: 22),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off, color: kHintText),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: InputBorder.none,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
                    ),
                    enabledBorder: InputBorder.none,
                  ),
                ),
                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: const Text('Forgot Password?', style: TextStyle(color: kBrownAccent)),
                  ),
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFD32F2F)), textAlign: TextAlign.center),
                  ),

                // Sign In Button
                SizedBox(
                  height: 55,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
                          child: const Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                ),
                const SizedBox(height: 32),

                // Separator
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('or', style: TextStyle(color: Colors.white70)),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                  ],
                ),
                const SizedBox(height: 32),

                // Google Sign-In
                SizedBox(
                  height: 55,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
                      : ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Image.asset(
                            'assets/images/google.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.android, color: Colors.white, size: 24),
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

                // Footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    children: [
                      const TextSpan(text: 'By continuing, you agree to our\n'),
                      TextSpan(
                        text: 'Term of Services',
                        style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () { /* TODO open link */ },
                      ),
                      const TextSpan(text: ' and '),
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
                        recognizer: TapGestureRecognizer()..onTap = () { /* TODO open link */ },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // custom widget: tab untuk login/signup
  // ========================================
  Widget _buildAuthTabs({required bool isLogin, required VoidCallback onSignUpTap}) {
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
          // - expanded membuat tab mengambil ruang sama rata
          // - container dengan background coklat untuk tab aktif
          // - text "log in" dengan alignment center
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: kBrownAccent, borderRadius: BorderRadius.circular(12)),
              child: const Text('Log in', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
          // penjelasan tab signup:
          // - gesturedetector untuk mendeteksi tap
          // - onTap callback untuk navigasi ke register screen
          // - container dengan background transparan
          Expanded(
            child: GestureDetector(
              onTap: onSignUpTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12)),
                child: const Text('Sign Up', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // custom widget: text input field
  // ========================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    // penjelasan:
    // - reusable widget untuk membuat input field dengan style yang konsisten
    // - controller: menangkap text yang user ketik
    // - hinttext: placeholder text saat field kosong
    // - icon: icon di sebelah kiri input
    // - keyboardtype: tipe keyboard yang muncul (email, number, text, dll)
    
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: kHintText),
        filled: true,
        fillColor: kDarkGrey,
        prefixIcon: Icon(icon, color: kHintText, size: 22),
        border: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
        ),
      ),
    );
  }
}
