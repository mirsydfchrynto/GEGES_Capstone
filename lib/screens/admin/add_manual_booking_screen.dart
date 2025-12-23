// lib/screens/admin/add_manual_booking_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/models/user_data.dart';

/// Add Manual Booking Screen
/// - Offline / Walk-in manual entry oleh admin/barber
/// - Validasi slot selalu dilakukan sebelum menyimpan
/// - Barberman dapat dipilih secara manual (atau otomatis berdasarkan akun admin/barber yang login)
/// - Layanan diambil dari koleksi `services` berdasarkan barbershop.services
class AddManualBookingScreen extends StatefulWidget {
  final Barbershop barbershop;
  const AddManualBookingScreen({super.key, required this.barbershop});

  @override
  State<AddManualBookingScreen> createState() => _AddManualBookingScreenState();
}

class _AddManualBookingScreenState extends State<AddManualBookingScreen> {
  // Theme tokens (sesuaikan dengan tema utama)
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkSurface = Color(0xFF121212);

  final _formKey = GlobalKey<FormState>();
  final BarbershopService _barbershopService = BarbershopService();

  // input fields
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  List<Service> _services = [];
  List<Barberman> _barbermen = [];

  final List<String> _selectedServiceIds = [];
  Barberman? _selectedBarberman;

  DateTime? _selectedDateTime;

  bool _loading = true;
  bool _saving = false;

  // current admin user data (to auto-assign barber if available)
  UserData? _currentUserData;

  // Formatters
  final DateFormat _dtLabel = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
  final NumberFormat _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _initAll();
  }

  Future<void> _initAll() async {
    setState(() => _loading = true);
    try {
      // 1) fetch current admin user data (if exists)
      if (_currentUserData != null) {
  final currentUid = FirebaseAuth.instance.currentUser?.uid;
  if (currentUid != null) {
    // cari barber dengan UID yang sama seperti akun login
    final maybe = _barbermen.firstWhere(
      (b) => b.id == currentUid,
      orElse: () => _barbermen.isNotEmpty ? _barbermen.first : Barberman(id: '', name: '', barbershopId: '', avgDuration: 0.0, rating: 0.0, isActive: true),
    );
    _selectedBarberman = maybe.id.isNotEmpty ? maybe : null;
  }
}

      // 2) fetch barbermen for this barbershop
      _barbermen = await _barbershopService.getBarbermenByShop(widget.barbershop.id);

      // 3) fetch services for this barbershop (by service IDs list inside barbershop)
      final allServices = await _barbershopService.getAllServices();
      final shopServiceIds = widget.barbershop.services.toSet();

      if (shopServiceIds.isEmpty) {
        // If barbershop.services empty, show all services as fallback
        _services = allServices;
      } else {
        _services = allServices.where((s) => shopServiceIds.contains(s.id)).toList();
      }

      // 4) Auto select barberman if current user is linked to a barberman (user.barbershopId could be used)
      if (_currentUserData != null) {
        // try to find barberman with uid equal to current user uid (common pattern)
        final currentUid = FirebaseAuth.instance.currentUser?.uid;
        if (currentUid != null) {
          final maybe = _barbermen.firstWhere(
            (b) => b.id == currentUid || b.id == (_currentUserData?.barbershopId ?? ''),
            orElse: () => Barberman(id: '', name: '', barbershopId: '', avgDuration: 0.0, rating: 0.0, isActive: true),
          );
          if (maybe.id.isNotEmpty) {
            _selectedBarberman = maybe;
          }
        }

        // Alternatively, some setups store barbermanId inside user doc
        // If user.barbershopId actually holds barberman id in your DB schema (unlikely), adapt accordingly.
      }

      // ensure barbermen list only active ones
      _barbermen = _barbermen.where((b) => b.isActive).toList();
    }catch (e, st) {
      debugPrint('Error initializing AddManualBookingScreen: $e\n$st');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Validate booking time: not in the past and within open/close hours
  String? _validateDateTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.isBefore(now.subtract(const Duration(minutes: 1)))) {
      return 'Waktu booking tidak boleh di masa lalu';
    }
    final open = widget.barbershop.openHour;
    final close = widget.barbershop.closeHour;
    if (dt.hour < open || dt.hour >= close) {
      return 'Waktu harus antara $open:00 - $close:00';
    }
    return null;
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: kBrownAccent),
        ),
        child: child!,
      ),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      // ignore: use_build_context_synchronously
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15))),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(primary: kBrownAccent),
        ),
        child: child!,
      ),
    );
    if (!mounted) return;
    if (pickedTime == null) return;

    final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);

    final err = _validateDateTime(dt);
    if (err != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    setState(() {
      _selectedDateTime = dt;
    });
  }

  int get _totalPrice {
    int total = 0;
    for (final id in _selectedServiceIds) {
      final s = _services.firstWhere((e) => e.id == id, orElse: () => Service(id: '', name: '', description: '', price: 0.0, defaultDuration: 30, isActive: true));
      total += s.price.toInt();
    }
    return total;
  }

  int get _totalDuration {
    int total = 0;
    for (final id in _selectedServiceIds) {
      final s = _services.firstWhere((e) => e.id == id, orElse: () => Service(id: '', name: '', description: '', price: 0.0, defaultDuration: 30, isActive: true));
      total += s.defaultDuration;
    }
    return total;
  }

  Future<void> _onSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // fallback assign barber otomatis jika belum dipilih
    if (_selectedBarberman == null && _barbermen.isNotEmpty) {
      _selectedBarberman = _barbermen.first; // barber aktif pertama
    }

    if (_selectedServiceIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih minimal 1 layanan')));
      return;
    }
    if (_selectedBarberman == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih barberman')));
      return;
    }
    if (_selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih tanggal & waktu')));
      return;
    }

    setState(() {});

    try {
      // create a synthetic customer id for manual booking (unique per manual booking)
      final manualCustomerId = 'manual_${DateTime.now().millisecondsSinceEpoch}';

      // Validate slot availability before saving
      final slotOk = await QueueService().isSlotAvailable(
        barbershopId: widget.barbershop.id,
        barbermanId: _selectedBarberman!.id,
        bookingTime: _selectedDateTime!,
        serviceIds: _selectedServiceIds,
      );

      if (!slotOk) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Slot tidak tersedia — bentrok dengan booking lain'), backgroundColor: Colors.orangeAccent));
        return;
      }

      final payload = {
        'barbershop_id': widget.barbershop.id,
        // Use a shared manual customer id so manual bookings are identifiable
        'customer_id': manualCustomerId,
        'customer_name': _nameCtrl.text.trim(),
        'customer_is_manual': true,
        'created_by_admin_uid': FirebaseAuth.instance.currentUser?.uid,
        'customer_phone': _phoneCtrl.text.trim(),
        'barberman_id': _selectedBarberman!.id,
        'service_ids': _selectedServiceIds,
        'total_price': _totalPrice,
        'estimated_duration': _totalDuration,
        'booking_time': Timestamp.fromDate(_selectedDateTime!),
        'status': 'booked',
        'payment_method': 'cash',
        'payment_amount': _totalPrice,
        'notes': _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      };

      if (mounted) {
        setState(() { _saving = true; });
      }
      await QueueService().createQueue(payload);
      if (mounted) {
        setState(() { _saving = false; });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking manual berhasil disimpan'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error creating manual booking: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat booking manual: ${e.toString()}'), backgroundColor: Colors.redAccent));
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Widget _buildServiceTile(Service s) {
    final selected = _selectedServiceIds.contains(s.id);
    return InkWell(
      onTap: () {
        setState(() {
          if (selected) {
            _selectedServiceIds.remove(s.id);
          } else {
            _selectedServiceIds.add(s.id);
          }
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color.fromRGBO(195,164,123,0.14) : const Color(0xFF161616),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? kBrownAccent : Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Checkbox(
              value: selected,
              onChanged: (_) {
                setState(() {
                  if (selected) {
                    _selectedServiceIds.remove(s.id);
                  } else {
                    _selectedServiceIds.add(s.id);
                  }
                });
              },
              activeColor: kBrownAccent,
              checkColor: Colors.black,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(s.name, style: const TextStyle(color: Colors.white))),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(_currency.format(s.price), style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text('${s.defaultDuration} m', style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ])
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalLabel = _currency.format(_totalPrice);
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kBrownAccent,
        title: const Text('Add Manual Booking', style: TextStyle(color: Colors.black)),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrownAccent))
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  const Text('Untuk pelanggan walk-in yang datang langsung ke barbershop', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 12),

                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color.fromRGBO(195,164,123,0.18))),
                    child: Row(children: const [
                      Icon(Icons.check_circle_outline, color: Color(0xFFC3A47B)),
                      SizedBox(width: 10),
                      Expanded(child: Text('Booking manual akan langsung masuk ke antrean tanpa perlu konfirmasi pembayaran.', style: TextStyle(color: Colors.white70))),
                    ]),
                  ),

                  const SizedBox(height: 18),

                  // Data Pelanggan
                  Card(
                    color: const Color(0xFF1B1B1B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.person, color: kBrownAccent), SizedBox(width: 8), Text('Data Pelanggan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _nameCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Nama lengkap pelanggan',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: const Color(0xFF121212),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Nama wajib diisi' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phoneCtrl,
                          style: const TextStyle(color: Colors.white),
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            hintText: '08xxxxxxxxxx (opsional)',
                            hintStyle: const TextStyle(color: Colors.white24),
                            filled: true,
                            fillColor: const Color(0xFF121212),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                          ),
                        ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Pilih Barberman (either auto-selected or pick from list)
                  Card(
                    color: const Color(0xFF1B1B1B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.person_search, color: kBrownAccent), SizedBox(width: 8), Text('Pilih Barberman', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 10),
                        if (_currentUserData != null && _selectedBarberman != null && _barbermen.any((b) => b.id == _selectedBarberman!.id))
                          // auto-selected barber if current user is a barber
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(_selectedBarberman!.name, style: const TextStyle(color: Colors.white)),
                              Text('~${_selectedBarberman!.avgDuration.toInt()} menit', style: const TextStyle(color: Colors.white70)),
                            ]),
                          )
                        else
                          Column(
                            children: _barbermen.map((b) {
                              final selected = _selectedBarberman?.id == b.id;
                              return InkWell(
                                onTap: () => setState(() => _selectedBarberman = b),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: selected ? const Color.fromRGBO(195,164,123,0.13) : const Color(0xFF151515),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: selected ? kBrownAccent : Colors.grey.shade800),
                                  ),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    Text(b.name, style: const TextStyle(color: Colors.white)),
                                    Text('~${b.avgDuration.toInt()} m', style: const TextStyle(color: Colors.white70)),
                                  ]),
                                ),
                              );
                            }).toList(),
                          ),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Pilih Layanan
                  Card(
                    color: const Color(0xFF1B1B1B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.content_cut, color: kBrownAccent), SizedBox(width: 8), Text('Pilih Layanan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 10),
                        if (_services.isEmpty)
                          const Text('Belum ada layanan untuk barbershop ini', style: TextStyle(color: Colors.white54))
                        else
                          Column(children: _services.map((s) => _buildServiceTile(s)).toList()),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Date & Time
                  Card(
                    color: const Color(0xFF1B1B1B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: const [Icon(Icons.access_time, color: kBrownAccent), SizedBox(width: 8), Text('Tanggal & Waktu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _pickDateTime,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                            decoration: BoxDecoration(color: const Color(0xFF151515), borderRadius: BorderRadius.circular(8)),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                              Text(
                                _selectedDateTime == null ? 'Pilih tanggal & waktu' : _dtLabel.format(_selectedDateTime!),
                                style: const TextStyle(color: Colors.white70),
                              ),
                              const Icon(Icons.calendar_today, color: kBrownAccent),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_totalDuration > 0)
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text('Estimasi durasi', style: const TextStyle(color: Colors.white70)),
                            Text('~$_totalDuration menit', style: const TextStyle(color: Colors.white)),
                          ]),
                      ]),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Notes
                  TextFormField(
                    controller: _notesCtrl,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Catatan (opsional)',
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true,
                      fillColor: const Color(0xFF151515),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Total & Buttons
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: const Color(0xFF171717), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Row(children: const [Icon(Icons.attach_money, color: Colors.greenAccent), SizedBox(width: 8), Text('Total Pembayaran', style: TextStyle(color: Colors.white70))]),
                        Text(totalLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // reset
                              setState(() {
                                _nameCtrl.clear();
                                _phoneCtrl.clear();
                                _notesCtrl.clear();
                                _selectedServiceIds.clear();
                                _selectedBarberman = null;
                                _selectedDateTime = null;
                              });
                            },
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade700),
                              backgroundColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Reset Form', style: TextStyle(color: Colors.white70)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _saving ? null : _onSubmit,
                            icon: const Icon(Icons.add),
                            label: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) : const Text('booking', style: TextStyle(color: Colors.black)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kBrownAccent,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ])
                    ]),
                  ),

                  const SizedBox(height: 30),
                ]),
              ),
            ),
    );
  }
}

/// Convenience factory function to avoid import/name resolution edge-cases.
Widget buildAddManualBookingScreen(Barbershop barbershop) => AddManualBookingScreen(barbershop: barbershop);
