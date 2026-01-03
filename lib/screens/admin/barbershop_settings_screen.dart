import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbershopSettingsScreen extends StatefulWidget {
  final Barbershop barbershop;
  const BarbershopSettingsScreen({required this.barbershop, super.key});

  @override
  State<BarbershopSettingsScreen> createState() => _BarbershopSettingsScreenState();
}

class _BarbershopSettingsScreenState extends State<BarbershopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late List<String> _facilities;
  final TextEditingController _facilityController = TextEditingController();
  
  bool _isLoading = false;
  final BarbershopService _service = BarbershopService();

  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkSurface = Color(0xFF1E1E1E);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.barbershop.name);
    _addressController = TextEditingController(text: widget.barbershop.addres);
    _facilities = List.from(widget.barbershop.facilities);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
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
        title: const Text('Barbershop Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
              _buildTextField(_nameController, 'Barbershop Name', Icons.storefront),
              const SizedBox(height: 15),
              _buildTextField(_addressController, 'Address / Location', Icons.location_on_outlined, maxLines: 3),
              
              const SizedBox(height: 30),
              _buildSectionTitle('Facilities'),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_facilityController, 'Add Facility (e.g. AC, Wifi)', Icons.add_box_outlined),
                  ),
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
                  labelStyle: const TextStyle(color: Colors.white),
                  deleteIcon: const Icon(Icons.close, size: 16, color: Colors.redAccent),
                  onDeleted: () => setState(() => _facilities.remove(f)),
                )).toList(),
              ),

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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold));
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: kBrownAccent),
        filled: true,
        fillColor: kDarkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Field cannot be empty' : null,
    );
  }
}
