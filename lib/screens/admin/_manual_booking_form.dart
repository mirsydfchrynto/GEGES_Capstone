import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
// cloud_firestore not required here

class ManualBookingForm extends StatefulWidget {
  final Barbershop barbershop;
  final QueueService queueService;
  const ManualBookingForm({
    super.key,
    required this.barbershop,
    required this.queueService,
  });

  @override
  State<ManualBookingForm> createState() => ManualBookingFormState();
}

class ManualBookingFormState extends State<ManualBookingForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  final BarbershopService _bs = BarbershopService();
  List<Service> _services = [];
  List<Barberman> _barbermen = [];
  final List<String> _selectedServiceIds = [];
  Barberman? _selectedBarberman;
  DateTime? _selectedDateTime;

  bool _submitting = false;

  final DateFormat _dtLabel = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    try {
      _barbermen = await _bs.getBarbermenByShop(widget.barbershop.id);
      final all = await _bs.getAllServices();
      final shopSet = widget.barbershop.services.toSet();
      _services = shopSet.isEmpty
          ? all
          : all.where((s) => shopSet.contains(s.id)).toList();
      if (_barbermen.isNotEmpty) {
        _selectedBarberman = _barbermen.first;
      }
    } catch (e) {
      debugPrint('Error init manual booking form: $e');
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null) return;
    if (!mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
    );
    if (pickedTime == null) return;
    setState(() {
      _selectedDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih tanggal & waktu')));
      return;
    }
    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih minimal satu layanan')),
      );
      return;
    }
    if (_selectedBarberman == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pilih barberman')));
      return;
    }

    setState(() => _submitting = true);

    try {
      // Check slot availability
      final isAvailable = await widget.queueService.isSlotAvailable(
        barbershopId: widget.barbershop.id,
        barbermanId: _selectedBarberman!.id,
        bookingTime: _selectedDateTime!,
        serviceIds: _selectedServiceIds,
      );

      if (!isAvailable) throw Exception('Slot tidak tersedia - bentrok');

      final manualCustomerId =
          'manual_${DateTime.now().millisecondsSinceEpoch}';

      final Map<String, dynamic> payload = {
        'barbershop_id': widget.barbershop.id,
        'barberman_id': _selectedBarberman!.id,
        'service_ids': _selectedServiceIds,
        'booking_time': _selectedDateTime,
        'status': 'booked',
        'payment_method': 'cash',
        'customer_id': manualCustomerId,
        'customer_name': _nameCtrl.text.trim(),
        'customer_is_manual': true,
        'notes': _notesCtrl.text.isEmpty ? null : _notesCtrl.text,
      };

      await widget.queueService.createQueue(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking manual berhasil dibuat')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal membuat booking: $e')));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Tambah Booking Manual - ${widget.barbershop.name}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nama Pelanggan',
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Nama harus diisi' : null,
                  ),
                  TextFormField(
                    controller: _phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nomor Telepon',
                    ),
                    validator: (v) => v == null || v.isEmpty
                        ? 'Nomor telepon harus diisi'
                        : null,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<Barberman?>(
                    initialValue: _selectedBarberman,
                    items: _barbermen
                        .map(
                          (b) =>
                              DropdownMenuItem(value: b, child: Text(b.name)),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _selectedBarberman = v;
                    }),
                    decoration: const InputDecoration(labelText: 'Barberman'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _services
                        .map(
                          (s) => FilterChip(
                            label: Text(s.name),
                            selected: _selectedServiceIds.contains(s.id),
                            onSelected: (sel) {
                              setState(() {
                                if (sel) {
                                  _selectedServiceIds.add(s.id);
                                } else {
                                  _selectedServiceIds.remove(s.id);
                                }
                              });
                            },
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedDateTime == null
                              ? 'Belum memilih waktu'
                              : _dtLabel.format(_selectedDateTime!),
                        ),
                      ),
                      TextButton(
                        onPressed: _pickDateTime,
                        child: const Text('Pilih Waktu'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const CircularProgressIndicator()
                        : const Text('Buat Booking'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
