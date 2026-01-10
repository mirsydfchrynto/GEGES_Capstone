import 'package:flutter/material.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  final AuthService _authService = AuthService();

  // Warna Tema
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Colors.black;
  static const Color kCardBg = Color(0xFF1E1E1E);

  @override
  void dispose() {
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.changePassword(
        currentPassword: _oldPassCtrl.text,
        newPassword: _newPassCtrl.text,
      );

      if (!mounted) return;
      
      // Sukses
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password berhasil diubah!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context); // Kembali ke profil
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Ganti Password', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: kBrownAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBrownAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_reset, color: kBrownAccent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Demi keamanan, mohon verifikasi password lama Anda sebelum membuat password baru.',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // 1. Password Lama
              _buildPasswordField(
                controller: _oldPassCtrl,
                label: 'Password Lama',
                obscure: _obscureOld,
                onToggle: () => setState(() => _obscureOld = !_obscureOld),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Password lama wajib diisi';
                  return null;
                },
              ),
              
              const SizedBox(height: 20),
              const Divider(color: Colors.white24),
              const SizedBox(height: 20),

              // 2. Password Baru
              _buildPasswordField(
                controller: _newPassCtrl,
                label: 'Password Baru',
                obscure: _obscureNew,
                onToggle: () => setState(() => _obscureNew = !_obscureNew),
                validator: (val) {
                  if (val == null || val.length < 6) return 'Minimal 6 karakter';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 3. Konfirmasi Password Baru
              _buildPasswordField(
                controller: _confirmPassCtrl,
                label: 'Konfirmasi Password Baru',
                obscure: _obscureConfirm,
                onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
                validator: (val) {
                  if (val != _newPassCtrl.text) return 'Password tidak cocok';
                  return null;
                },
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black) 
                    : const Text('UPDATE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        filled: true,
        fillColor: kCardBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kBrownAccent)),
        errorStyle: const TextStyle(color: Colors.redAccent),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off : Icons.visibility,
            color: Colors.white54,
          ),
          onPressed: onToggle,
        ),
      ),
    );
  }
}
