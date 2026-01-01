import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbershopSettingsScreen extends StatefulWidget {
  final Barbershop barbershop;
  final BarbershopService? service;

  const BarbershopSettingsScreen({super.key, required this.barbershop, this.service});

  @override
  State<BarbershopSettingsScreen> createState() => _BarbershopSettingsScreenState();
}

class _BarbershopSettingsScreenState extends State<BarbershopSettingsScreen> {
  late final BarbershopService _svc;
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _feeController = TextEditingController();
  final TextEditingController _specificHolidayController = TextEditingController();
  
  int _openHour = 9;
  int _closeHour = 21;
  List<int> _weeklyHolidays = [];
  List<String> _specificHolidays = [];
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? BarbershopService();
    _feeController.text = (widget.barbershop.barberSelectionFee).toString();
    _openHour = widget.barbershop.openHour;
    _closeHour = widget.barbershop.closeHour;
    _weeklyHolidays = List.from(widget.barbershop.weeklyHolidays);
    _specificHolidays = List.from(widget.barbershop.specificHolidays);
  }

  @override
  void dispose() {
    _feeController.dispose();
    _specificHolidayController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    try {
      final payload = {
        'barber_selection_fee': int.parse(_feeController.text),
        'open_hour': _openHour,
        'close_hour': _closeHour,
        'weekly_holidays': _weeklyHolidays,
        'specific_holidays': _specificHolidays,
      };
      
      // Update via firestore directly for multiple fields
      if (widget.barbershop.id.isNotEmpty) {
        await _svc.updateBarbershopSettings(widget.barbershop.id, payload);
      }
      
      // Since we don't have a dedicated "updateFullSettings" method in service, let's update specific fields
      // For this implementation, I'll update the barbershop document directly
      // In a real scenario, you'd add this to BarbershopService
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pengaturan Berhasil Disimpan')));
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toggleWeeklyHoliday(int day) {
    setState(() {
      if (_weeklyHolidays.contains(day)) {
        _weeklyHolidays.remove(day);
      } else {
        _weeklyHolidays.add(day);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color kBrownAccent = Color(0xFFC3A47B);
    const Color kSurface = Color(0xFF0F0F0F);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Pengaturan Barbershop', style: TextStyle(color: Colors.white)),
        backgroundColor: kSurface,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _section("Special Order Fee (Rp)"),
            TextFormField(
              controller: _feeController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                fillColor: Colors.white10, filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                hintText: 'Misal: 5000', hintStyle: const TextStyle(color: Colors.white24),
              ),
            ),
            
            const SizedBox(height: 32),
            _section("Jam Operasional"),
            Row(
              children: [
                Expanded(child: _hourPicker("Buka", _openHour, (v) => setState(() => _openHour = v))),
                const SizedBox(width: 20),
                Expanded(child: _hourPicker("Tutup", _closeHour, (v) => setState(() => _closeHour = v))),
              ],
            ),

            const SizedBox(height: 32),
            _section("Hari Libur Mingguan"),
            Wrap(
              spacing: 8,
              children: List.generate(7, (index) {
                final days = ["Minggu", "Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu"];
                bool isHoliday = _weeklyHolidays.contains(index);
                return FilterChip(
                  label: Text(days[index]),
                  selected: isHoliday,
                  onSelected: (_) => _toggleWeeklyHoliday(index),
                  selectedColor: kBrownAccent,
                  labelStyle: TextStyle(color: isHoliday ? Colors.black : Colors.white),
                  backgroundColor: Colors.white10,
                );
              }),
            ),

            const SizedBox(height: 32),
            _section("Libur Khusus (Tanggal)"),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _specificHolidayController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: "Tambah Tanggal Libur",
                      fillColor: Colors.white10, filled: true,
                      suffixIcon: IconButton(icon: const Icon(Icons.calendar_today, color: kBrownAccent), onPressed: () async {
                        final picked = await showDatePicker(
                          context: context, initialDate: DateTime.now(),
                          firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365))
                        );
                        if (picked != null) {
                          final str = DateFormat('yyyy-MM-dd').format(picked);
                          if (!_specificHolidays.contains(str)) {
                            setState(() => _specificHolidays.add(str));
                          }
                        }
                      }),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _specificHolidays.map((date) => Chip(
                label: Text(date),
                onDeleted: () => setState(() => _specificHolidays.remove(date)),
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                labelStyle: const TextStyle(color: Colors.white),
              )).toList(),
            ),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent, minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: _isSaving ? const CircularProgressIndicator(color: Colors.black) : const Text("SIMPAN PERUBAHAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.bold)),
  );

  Widget _hourPicker(String label, int current, Function(int) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
          child: DropdownButton<int>(
            value: current, isExpanded: true, dropdownColor: Colors.grey[900], underline: const SizedBox(),
            items: List.generate(24, (i) => DropdownMenuItem(value: i, child: Text("$i:00", style: const TextStyle(color: Colors.white)))),
            onChanged: (v) => v != null ? onSelected(v) : null,
          ),
        )
      ],
    );
  }
}