import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class EditProfileScreen extends StatefulWidget {
  final UserData currentUser;

  const EditProfileScreen({required this.currentUser, super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  bool _isLoading = false;

  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _emailController = TextEditingController(
      text: _authService.currentUser?.email ?? 'email@example.com',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<String?> _askForPassword() async {
    String password = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kDarkGrey,
          title: const Text('Konfirmasi Password', style: TextStyle(color: Colors.white)),
          content: TextField(
            autofocus: true,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(hintText: 'Masukkan password Anda'),
            onChanged: (v) => password = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(password),
              child: const Text('Lanjut'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newName = _nameController.text.trim();
    final newEmail = _emailController.text.trim();
    final oldEmail = _authService.currentUser?.email ?? '';

    try {
      final result = await _authService.updateProfile(
        uid: widget.currentUser.uid,
        newName: newName,
        newEmail: newEmail,
      );

      if (result['success']) {
        if (newEmail != oldEmail) {
          _showEmailVerificationDialog(newEmail);
        } else {
          final updatedData = UserData(
            uid: widget.currentUser.uid,
            name: newName,
            role: widget.currentUser.role,
          );
          _showSnackbar(result['message'], const Color(0xFF4CAF50));
          if (mounted) Navigator.pop(context, updatedData);
        }
      } else {
        // Jika butuh reauth (misalnya update email)
        if (result['code'] == 'requires-recent-login') {
          final password = await _askForPassword();
          if (password != null && password.isNotEmpty) {
            final retry = await _authService.reauthAndUpdateProfile(
              uid: widget.currentUser.uid,
              newName: newName,
              newEmail: newEmail,
              currentPassword: password,
            );

            if (retry['success']) {
              if (newEmail != oldEmail) {
                _showEmailVerificationDialog(newEmail);
              } else {
                final updatedData = UserData(
                  uid: widget.currentUser.uid,
                  name: newName,
                  role: widget.currentUser.role,
                );
                _showSnackbar(retry['message'], const Color(0xFF4CAF50));
                if (mounted) Navigator.pop(context, updatedData);
              }
            } else {
              _showSnackbar(retry['message'] ?? 'Re-auth gagal.', const Color(0xFFD32F2F));
            }
          } else {
            _showSnackbar('Password diperlukan untuk meng-update email.', const Color(0xFFD32F2F));
          }
        } else {
          _showSnackbar(result['message'] ?? 'Gagal memperbarui profil.', const Color(0xFFD32F2F));
        }
      }
    } catch (e) {
  _showSnackbar('Terjadi kesalahan: $e', const Color(0xFFD32F2F));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEmailVerificationDialog(String newEmail) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: kDarkGrey,
        title: const Text('Verifikasi Email Baru', style: TextStyle(color: Colors.white)),
        content: Text(
          'Kami telah mengirimkan link verifikasi ke:\n\n$newEmail\n\n'
          'Silakan buka email tersebut dan klik link verifikasi sebelum login kembali.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kBrownAccent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showSnackbar('Email verifikasi telah dikirim ke $newEmail', kBrownAccent);
              Navigator.pop(context); // Tutup layar edit
            },
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
  _showSnackbar('Masukkan email Anda untuk reset password.', const Color(0xFFD32F2F));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await _authService.sendPasswordResetEmail(email: email);
  _showSnackbar(result['message'], result['success'] ? kBrownAccent : const Color(0xFFD32F2F));
    } catch (e) {
  _showSnackbar('Gagal mengirim reset password: $e', const Color(0xFFD32F2F));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Edit Profile', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(
                      radius: 60,
                      backgroundColor: kDarkGrey,
                      child: Icon(Icons.person, size: 50, color: kTextGrey),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: kBrownAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: kSurface, width: 3),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.black, size: 20),
                          onPressed: () {
                            _showSnackbar('Fitur ganti foto belum diimplementasikan.', kBrownAccent);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              _buildTextField(
                controller: _nameController,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (value) => value == null || value.isEmpty ? 'Nama tidak boleh kosong' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailController,
                label: 'Email Address',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (value) =>
                    value == null || !value.contains('@') ? 'Masukkan email yang valid' : null,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _changePassword,
                icon: const Icon(Icons.lock_outline, color: kBrownAccent),
                label: const Text('Change Password', style: TextStyle(color: Colors.white)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  side: const BorderSide(color: kBrownAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveProfile,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 55),
                  backgroundColor: kBrownAccent,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3),
                      )
                    : const Text('SAVE CHANGES',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kTextGrey),
        prefixIcon: Icon(icon, color: kBrownAccent),
        filled: true,
        fillColor: kDarkGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.white12, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: kBrownAccent, width: 2),
        ),
      ),
    );
  }
}
