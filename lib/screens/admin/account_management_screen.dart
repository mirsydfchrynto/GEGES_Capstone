// lib/screens/admin/account_management_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/widgets/app_image.dart';
import 'package:geges_smartbarber/screens/common/change_password_screen.dart';

const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kSurface = Colors.black;

class AccountManagementScreen extends StatefulWidget {
  final String userId;
  final AuthService? authService;
  const AccountManagementScreen({super.key, required this.userId, this.authService});

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  late final AuthService _authService;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  
  String? _photoBase64;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
    _nameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await _authService.getUserById(widget.userId);
      if (user != null && mounted) {
        setState(() {
          _nameCtrl.text = user.name;
          _phoneCtrl.text = user.phoneNumber ?? '';
          _emailCtrl.text = _authService.auth.currentUser?.email ?? '';
          _photoBase64 = user.photoBase64;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, maxWidth: 500, maxHeight: 500, imageQuality: 70);
    if (image != null) {
      final bytes = await image.readAsBytes();
      setState(() {
        _photoBase64 = base64Encode(bytes);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await _authService.updateProfile(
        uid: widget.userId,
        newName: _nameCtrl.text.trim(),
        newPhoneNumber: _phoneCtrl.text.trim(),
        newPhotoBase64: _photoBase64,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil berhasil diperbarui'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Akun Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kSurface,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: kDarkGrey,
                          child: _photoBase64 != null 
                            ? AppImage(
                                base64: _photoBase64,
                                borderRadius: BorderRadius.circular(50),
                                fit: BoxFit.cover,
                              )
                            : const Icon(Icons.person, size: 50, color: Colors.white54),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _pickImage,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: kBrownAccent,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 20, color: Colors.black),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  
                  _buildTextField('Nama Lengkap', _nameCtrl, Icons.person_outline),
                  const SizedBox(height: 16),
                  _buildTextField('Nomor Telepon', _phoneCtrl, Icons.phone_outlined, isNumber: true),
                  const SizedBox(height: 16),
                  _buildTextField('Email (Read Only)', _emailCtrl, Icons.email_outlined, isReadOnly: true),
                  
                  const SizedBox(height: 30),
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kBrownAccent,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _isSaving 
                        ? const CircularProgressIndicator(color: Colors.black)
                        : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16)),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                      );
                    },
                    icon: const Icon(Icons.lock_reset, color: Colors.white70),
                    label: const Text('GANTI PASSWORD', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _buildTextField(String label, TextEditingController ctrl, IconData icon, {bool isNumber = false, bool isReadOnly = false}) {
    return TextFormField(
      controller: ctrl,
      readOnly: isReadOnly,
      keyboardType: isNumber ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: isReadOnly ? Colors.white54 : Colors.white),
      validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: kBrownAccent),
        filled: true,
        fillColor: kDarkGrey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
    );
  }
}