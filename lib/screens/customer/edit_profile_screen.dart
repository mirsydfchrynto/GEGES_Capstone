import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/services/auth_service.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;
const Color kTextGrey = Colors.white70;

class EditProfileScreen extends StatefulWidget {
  final UserData currentUser;
  final AuthService? authService;

  const EditProfileScreen({required this.currentUser, this.authService, super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  
  String? _newPhotoBase64;
  bool _isLoading = false;

  late final AuthService _authService;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _nameController = TextEditingController(text: widget.currentUser.name);
    _emailController = TextEditingController(
      text: _authService.currentUser?.email ?? '',
    );
    _phoneController = TextEditingController(text: widget.currentUser.phoneNumber ?? '');
    _newPhotoBase64 = widget.currentUser.photoBase64;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512, // Kompres ukuran untuk Firestore
        maxHeight: 512,
        imageQuality: 75,
      );
      
      if (image != null) {
        final bytes = await File(image.path).readAsBytes();
        setState(() {
          _newPhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      _showSnackbar('Gagal mengambil gambar: $e', const Color(0xFFD32F2F));
    }
  }

  Future<String?> _askForPassword() async {
    String password = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: kDarkGrey,
          title: const Text(
            'Konfirmasi Password',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            autofocus: true,
            obscureText: true,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              hintText: 'Masukkan password Anda',
            ),
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
    final newPhone = _phoneController.text.trim();
    final oldEmail = _authService.currentUser?.email ?? '';

    try {
      final result = await _authService.updateProfile(
        uid: widget.currentUser.uid,
        newName: newName,
        newEmail: newEmail,
        newPhoneNumber: newPhone,
        newPhotoBase64: _newPhotoBase64,
      );

      if (result['success']) {
        if (newEmail != oldEmail) {
          _showEmailVerificationDialog(newEmail);
        } else {
          final updatedData = widget.currentUser.copyWith(
            name: newName,
            phoneNumber: newPhone,
            photoBase64: _newPhotoBase64,
          );
          _showSnackbar(result['message'], const Color(0xFF4CAF50));
          if (mounted) Navigator.pop(context, updatedData);
        }
      } else {
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
              // Update phone & photo separately after reauth if needed
              await _authService.updateProfile(
                uid: widget.currentUser.uid,
                newName: newName,
                newPhoneNumber: newPhone,
                newPhotoBase64: _newPhotoBase64,
              );

              if (newEmail != oldEmail) {
                _showEmailVerificationDialog(newEmail);
              } else {
                final updatedData = widget.currentUser.copyWith(
                  name: newName,
                  phoneNumber: newPhone,
                  photoBase64: _newPhotoBase64,
                );
                _showSnackbar(retry['message'], const Color(0xFF4CAF50));
                if (mounted) Navigator.pop(context, updatedData);
              }
            } else {
              _showSnackbar(retry['message'] ?? 'Re-auth gagal.', const Color(0xFFD32F2F));
            }
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
          'Kami telah mengirimkan link verifikasi ke:\n\n$newEmail\n\nSilakan buka email tersebut.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pop(context);
            },
            child: const Text('Oke'),
          ),
        ],
      ),
    );
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
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
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildPhotoPicker(),
              const SizedBox(height: 40),
              _buildTextField(
                controller: _nameController,
                label: 'Nama Lengkap',
                icon: Icons.person_outline,
                validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _emailController,
                label: 'Email',
                icon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                validator: (v) => v == null || !v.contains('@') ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _phoneController,
                label: 'Nomor Telepon',
                icon: Icons.phone_android_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.black)
                      : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoPicker() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 70,
            backgroundColor: kDarkGrey,
            backgroundImage: _newPhotoBase64 != null 
                ? MemoryImage(base64Decode(_newPhotoBase64!))
                : null,
            child: _newPhotoBase64 == null 
                ? const Icon(Icons.person, size: 70, color: Colors.white24)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kBrownAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: kSurface, width: 4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 2),
                  ],
                ),
                child: const Icon(Icons.camera_alt, color: Colors.black, size: 24),
              ),
            ),
          ),
        ],
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: kBrownAccent)),
      ),
    );
  }
}