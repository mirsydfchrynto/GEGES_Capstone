import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbershopSettingsScreen extends StatefulWidget {
  final Barbershop barbershop;
  final BarbershopService? barbershopService;

  const BarbershopSettingsScreen({
    required this.barbershop,
    this.barbershopService,
    super.key,
  });

  @override
  State<BarbershopSettingsScreen> createState() =>
      _BarbershopSettingsScreenState();
}

class _BarbershopSettingsScreenState extends State<BarbershopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _googleMapsController;
  late TextEditingController _openHourController;
  late TextEditingController _closeHourController;

  late TextEditingController _instagramController;
  late TextEditingController _whatsappController;
  late TextEditingController _tiktokController;
  late TextEditingController _facebookController;
  late TextEditingController _twitterController;

  late List<String> _facilities;
  final TextEditingController _facilityController = TextEditingController();

  bool _isLoading = false;
  late final BarbershopService _service;

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkSurface = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _service = widget.barbershopService ?? BarbershopService();
    final s = widget.barbershop;
    _nameController = TextEditingController(text: s.name);
    _addressController = TextEditingController(text: s.addres);
    _googleMapsController = TextEditingController(text: s.googleMapsUrl ?? '');
    _openHourController = TextEditingController(text: s.openHour.toString());
    _closeHourController = TextEditingController(text: s.closeHour.toString());
    
    _instagramController = TextEditingController(text: s.instagramUrl ?? '');
    _whatsappController = TextEditingController(text: s.whatsappNumber ?? '');
    _tiktokController = TextEditingController(text: s.tiktokUrl ?? '');
    _facebookController = TextEditingController(text: s.facebookUrl ?? '');
    _twitterController = TextEditingController(text: s.twitterUrl ?? '');
    
    _facilities = List.from(s.facilities);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _googleMapsController.dispose();
    _openHourController.dispose();
    _closeHourController.dispose();
    _instagramController.dispose();
    _whatsappController.dispose();
    _tiktokController.dispose();
    _facebookController.dispose();
    _twitterController.dispose();
    _facilityController.dispose();
    super.dispose();
  }

  void _addFacility() {
    final text = _facilityController.text.trim();
    if (text.isNotEmpty && !_facilities.contains(text)) {
      setState(() {
        _facilities.add(text);
        _facilityController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    try {
      await _service.updateBarbershopSettings(widget.barbershop.id, {
        'name': _nameController.text.trim(),
        'address': _addressController.text.trim(),
        'google_maps_url': _googleMapsController.text.trim(),
        'open_hour': int.tryParse(_openHourController.text) ?? 9,
        'close_hour': int.tryParse(_closeHourController.text) ?? 21,
        'instagram_url': _instagramController.text.trim(),
        'whatsapp_number': _whatsappController.text.trim(),
        'tiktok_url': _tiktokController.text.trim(),
        'facebook_url': _facebookController.text.trim(),
        'twitter_url': _twitterController.text.trim(),
        'facilities': _facilities,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settings updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Manage Barbershop', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kBrownAccent,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Basic Information'),
              const SizedBox(height: 15),
              _buildTextField(_nameController, 'Barbershop Name', Icons.storefront, validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
              const SizedBox(height: 15),
              _buildTextField(_addressController, 'Address Description', Icons.location_on_outlined, maxLines: 2, validator: (v) => v == null || v.isEmpty ? 'Wajib diisi' : null),
              const SizedBox(height: 15),
              _buildTextField(_googleMapsController, 'Google Maps URL (Link)', Icons.map_outlined),
              
              const SizedBox(height: 30),
              _buildSectionTitle('Working Hours (24h format)'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(_openHourController, 'Open Hour', Icons.login, keyboardType: TextInputType.number)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField(_closeHourController, 'Close Hour', Icons.logout, keyboardType: TextInputType.number)),
                ],
              ),

              const SizedBox(height: 30),
              _buildSectionTitle('Facilities'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField(_facilityController, 'Add Facility', Icons.add_box_outlined)),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _addFacility,
                    style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black),
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 8,
                children: _facilities.map((f) => Chip(
                  label: Text(f),
                  backgroundColor: kDarkSurface,
                  labelStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  deleteIcon: const Icon(Icons.close, size: 14, color: Colors.redAccent),
                  onDeleted: () => setState(() => _facilities.remove(f)),
                )).toList(),
              ),

              const SizedBox(height: 30),
              _buildSectionTitle('Social Media Links'),
              const SizedBox(height: 15),
              _buildTextField(_instagramController, 'Instagram URL', Icons.camera_alt_outlined),
              const SizedBox(height: 12),
              _buildTextField(_whatsappController, 'WhatsApp (e.g. 62812...)', Icons.chat_outlined),
              const SizedBox(height: 12),
              _buildTextField(_tiktokController, 'TikTok URL', Icons.music_note_outlined),
              const SizedBox(height: 12),
              _buildTextField(_facebookController, 'Facebook URL', Icons.facebook_outlined),
              const SizedBox(height: 12),
              _buildTextField(_twitterController, 'Twitter/X URL', Icons.close),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kBrownAccent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('SAVE ALL CHANGES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1, String? Function(String?)? validator, TextInputType keyboardType = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 14),
        prefixIcon: Icon(icon, color: kBrownAccent, size: 20),
        filled: true,
        fillColor: kDarkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }
}