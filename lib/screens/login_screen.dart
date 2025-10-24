import 'package:flutter/material.dart';
// Pastikan service dan screens sudah diimport dengan path yang benar
import 'package:geges_smartbarber/services/auth_service.dart'; 
import 'package:geges_smartbarber/screens/customer/home_screen.dart'; 
import 'package:geges_smartbarber/screens/admin_web/admin_dashboard.dart'; 
// Import RegisterScreen
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

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Email dan password wajib diisi.');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Panggil AuthService untuk login dan Role Check
    Map<String, dynamic> result = await _authService.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      // NAVIGASI BERDASARKAN ROLE
      Widget targetScreen;
      if (result['role'] == 'customer') {
        targetScreen = const HomeScreen(); 
      } else if (result['role'] == 'admin_owner') {
        targetScreen = const AdminDashboardScreen(); // Target Tim 2
      } else {
        // Fallback jika role tidak terdefinisi
        targetScreen = const LoginScreen(); 
        setState(() => _errorMessage = 'Role pengguna tidak valid.');
      }
      
      // Navigasi ke Halaman yang Tepat
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => targetScreen), 
      );
      
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Login gagal. Cek kredensial Anda.');
    }
  }
  
  // Fungsi Register diaktifkan untuk navigasi
  void _goToRegister() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => const RegisterScreen()));
    setState(() => _errorMessage = ''); // Clear error saat pindah
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login GEGES SmartBarber')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Masuk',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Input Email
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
              const SizedBox(height: 16),
              
              // Input Password
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
              const SizedBox(height: 24),

              // Pesan Error
              if (_errorMessage.isNotEmpty) 
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(_errorMessage, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ),
              
              // Tombol Login
              SizedBox(
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _login, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('MASUK', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
              ),
              const SizedBox(height: 16),
              
              // Tombol Register (Diaktifkan)
              TextButton(
                onPressed: _goToRegister, 
                child: const Text('Belum punya akun? Daftar sekarang!'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

