import 'package:flutter/material.dart';
// Pastikan path ke auth_service.dart sudah benar
import 'package:geges_smartbarber/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String _errorMessage = '';
  bool _isLoading = false;

  void _register() async {
    // Validasi input sederhana
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Semua field wajib diisi.');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Panggil AuthService untuk mendaftarkan user dengan role 'customer'
    Map<String, dynamic> result = await _authService.registerCustomer(
      email: _emailController.text,
      password: _passwordController.text,
      name: _nameController.text,
    );

    setState(() => _isLoading = false);

    if (result['success']) {
      // Pendaftaran berhasil, kembali ke login screen
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Pendaftaran berhasil! Silakan login.')),
      );
      // Kembali ke LoginScreen setelah sukses
      Navigator.pop(context); 
    } else {
      setState(() => _errorMessage = result['message'] ?? 'Pendaftaran gagal.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Akun Baru'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Daftar Customer',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),

              // Input Nama
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                ),
              ),
              const SizedBox(height: 16),
              
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
                  labelText: 'Password (min 6 karakter)',
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
              
              // Tombol Daftar
              SizedBox(
                height: 50,
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ElevatedButton(
                        onPressed: _register, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('DAFTAR', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
              ),
              const SizedBox(height: 16),
              
              // Tombol Kembali
              TextButton(
                onPressed: () => Navigator.pop(context), 
                child: const Text('Sudah punya akun? Kembali ke Login.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

