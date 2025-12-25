import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbershopSettingsScreen extends StatefulWidget {
  final Barbershop barbershop;
  final BarbershopService? service;

  const BarbershopSettingsScreen({
    super.key,
    required this.barbershop,
    this.service,
  });

  @override
  State<BarbershopSettingsScreen> createState() => _BarbershopSettingsScreenState();
}

class _BarbershopSettingsScreenState extends State<BarbershopSettingsScreen> {
  late final BarbershopService _svc;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _feeController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? BarbershopService();
    _feeController.text = (widget.barbershop.specialOrderFee ?? 0).toString();
  }

  @override
  void dispose() {
    _feeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final fee = int.tryParse(_feeController.text.replaceAll(',', '')) ?? 0;
    setState(() => _isSaving = true);
    try {
      await _svc.updateSpecialOrderFee(widget.barbershop.id, fee);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to save: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Special Order Fee (Rp)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _feeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  hintText: 'Enter amount in rupiah, e.g., 5000',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Enter fee or 0';
                  final n = int.tryParse(v.replaceAll(',', ''));
                  if (n == null) return 'Invalid number';
                  if (n < 0) return 'Must be >= 0';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    child: _isSaving ? const CircularProgressIndicator() : const Text('Save'),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
