// NAMA FILE: lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/screens/admin/admin_dashboard.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword = true;

  // Theme
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kHintText = Color(0xFF6B6B6B);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // LOGIN EMAIL/PASSWORD
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Email dan password wajib diisi.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _authService.signIn(email: email, password: password);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _navigateByRole(result['role']);
      } else {
        setState(() => _errorMessage = result['message'] ?? 'Login gagal.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Terjadi kesalahan: $e';
      });
    }
  }

  // NAVIGASI BERDASARKAN ROLE
  void _navigateByRole(String? role) {
    Widget targetScreen;
    if (role == 'customer') {
      targetScreen = const HomeScreen();
    } else if (role == 'admin_owner') {
      targetScreen = const AdminDashboardScreen();
    } else {
      setState(() => _errorMessage = 'Role pengguna tidak valid.');
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => targetScreen),
    );
  }

  // GO TO REGISTER SCREEN
  void _goToRegister() {
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

  // FORGOT PASSWORD: Minta email lalu panggil service
  void _forgotPassword() async {
    final email = _emailController.text.trim();

    // Jika email kosong, minta input lewat dialog
    if (email.isEmpty) {
      final typed = await _askForEmailDialog();
      if (typed == null || typed.trim().isEmpty) {
        _showSnackbar('Masukkan email untuk menerima link reset.', Colors.redAccent);
        return;
      }
      await _sendResetEmail(typed.trim());
      return;
    }

    await _sendResetEmail(email);
  }

  Future<void> _sendResetEmail(String email) async {
    setState(() => _isLoading = true);
    try {
      final res = await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _showSnackbar('Link reset password telah dikirim ke $email.', kBrownAccent);
      } else {
        _showSnackbar(res['message'] ?? 'Gagal mengirim link reset password.', Colors.redAccent);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar('Terjadi kesalahan: $e', Colors.redAccent);
    }
  }

  // GOOGLE SIGN-IN
  // GOOGLE SIGN-IN
void _signInWithGoogle() async {
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
      final message = result['message'] ?? 'Google sign-in gagal.';
      // Tampilkan snackbar (lebih friendly) dan juga simpan ke _errorMessage
      _showSnackbar(message, Colors.redAccent);
      setState(() => _errorMessage = message);
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Terjadi kesalahan: $e';
    });
    _showSnackbar('Terjadi kesalahan: $e', Colors.redAccent);
  }
}


  // DIALOG: Minta Email untuk Reset Password
  Future<String?> _askForEmailDialog() async {
    String typed = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: const Text('Reset Password', style: TextStyle(color: Colors.white)),
          content: TextField(
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Masukkan email Anda'),
            onChanged: (v) => typed = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
              onPressed: () => Navigator.of(context).pop(typed),
              child: const Text('Kirim'),
            ),
          ],
        );
      },
    );
  }

  // UI: Snackbar helper
  void _showSnackbar(String msg, Color color) {
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
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
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

  Widget _buildAuthTabs({required bool isLogin, required VoidCallback onSignUpTap}) {
    return Container(
      decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(color: kBrownAccent, borderRadius: BorderRadius.circular(12)),
              child: const Text('Log in', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
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
