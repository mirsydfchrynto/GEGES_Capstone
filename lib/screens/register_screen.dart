// NAMA FILE: lib/screens/register_screen.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/screens/login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _errorMessage = '';
  bool _isLoading = false;

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kHintText = Color(0xFF6B6B6B);

  // 🔹 Fungsi daftar dengan Firebase + verifikasi email
  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _errorMessage = 'Semua field wajib diisi.');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Password dan konfirmasi tidak cocok.');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorMessage = 'Password minimal 6 karakter.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // 🔹 1. Buat akun baru
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'null-user', message: 'Gagal membuat akun.');
      }

      // 🔹 2. Update displayName di Auth dan buat dokumen Firestore
      await user.updateDisplayName(name);
      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': email,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      // 🔹 3. Kirim email verifikasi
      await user.sendEmailVerification();

      // 🔹 4. Tampilkan pesan sukses
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pendaftaran sukses! Verifikasi email telah dikirim ke $email'),
          backgroundColor: Colors.green,
        ),
      );

      // 🔹 5. Kembali ke LoginScreen
      _goToLogin();
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'Email sudah terdaftar. Gunakan email lain.';
          break;
        case 'invalid-email':
          msg = 'Format email tidak valid.';
          break;
        case 'weak-password':
          msg = 'Password terlalu lemah.';
          break;
        default:
          msg = e.message ?? 'Terjadi kesalahan saat registrasi.';
      }
      setState(() => _errorMessage = msg);
    } catch (e) {
      setState(() => _errorMessage = 'Terjadi kesalahan: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionDuration: Duration.zero,
      ),
    );
  }

  void _signInWithGoogle() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fitur "Sign in with Google" belum diimplementasikan.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/geges.png',
                height: 120,
                errorBuilder: (_, __, ___) =>
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
              _buildAuthTabs(isLogin: false, onLoginTap: _goToLogin),
              const SizedBox(height: 32),

              _buildTextField(_nameController, 'Username', Icons.person_outline),
              const SizedBox(height: 16),
              _buildTextField(_emailController, 'Email', Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 16),
              _buildTextField(_passwordController, 'Password', Icons.lock_outline, isObscure: true),
              const SizedBox(height: 16),
              _buildTextField(_confirmPasswordController, 'Confirm Password', Icons.lock_outline,
                  isObscure: true),
              const SizedBox(height: 20),

              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(_errorMessage,
                      style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
                ),

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

              _buildSeparator(),
              const SizedBox(height: 32),

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
              _buildFooterTerms(),
            ],
          ),
        ),
      ),
    );
  }

  // --- UI Helper Widgets ---
  Widget _buildAuthTabs({required bool isLogin, required VoidCallback onLoginTap}) {
    return Container(
      decoration: BoxDecoration(color: kDarkGrey, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
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

  Widget _buildTextField(TextEditingController c, String hint, IconData icon,
      {bool isObscure = false, TextInputType keyboardType = TextInputType.text}) {
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

  Widget _buildSeparator() {
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

  Widget _buildFooterTerms() {
    return RichText(
      textAlign: TextAlign.center,
      text: TextSpan(
        style: const TextStyle(color: Colors.white54, fontSize: 12),
        children: [
          const TextSpan(text: 'By continuing, you agree to our\n'),
          TextSpan(
              text: 'Terms of Services',
              style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () => print('Terms of Services')),
          const TextSpan(text: ' and '),
          TextSpan(
              text: 'Privacy Policy',
              style: const TextStyle(color: kBrownAccent, decoration: TextDecoration.underline),
              recognizer: TapGestureRecognizer()..onTap = () => print('Privacy Policy')),
        ],
      ),
    );
  }
}
