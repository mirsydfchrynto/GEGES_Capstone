// lib/screens/customer/appointment_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:geges_smartbarber/services/queue_service.dart';

// Import Halaman Pembayaran
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

class AppointmentScreen extends StatefulWidget {
  final Barbershop barbershop;
  const AppointmentScreen({super.key, required this.barbershop});

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  final BarbershopService _barbershopService = BarbershopService();
  final QueueService _queueService = QueueService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Theme tokens
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Color(0xFF0F0F0F);

  // Formatters
  final DateFormat _dateFormat = DateFormat('EEEE, dd MMM yyyy', 'id_ID');
  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final DateFormat _timeFormat = DateFormat('HH:mm', 'id_ID');

  // State
  final List<Service> _selectedServices = [];
  Barberman? _selectedBarberman;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  DateTime? _estimatedFinishTime;
  bool _isLoading = false;
  String _slotAvailabilityMessage = '';
  bool _isSlotAvailable = false;

  // Futures
  late Future<List<Service>> _servicesFuture;
  late Future<List<Barberman>> _barbermenFuture;

  // Layout constants
  static const double kBottomBuffer = 100.0; // Jarak aman di atas bottom bar

  // totals
  int get _totalPrice => _selectedServices.fold(0, (acc, e) => acc + e.price.toInt());
  int get _totalDuration =>
      _selectedServices.fold(0, (acc, e) => acc + e.defaultDuration);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    // set next quarter hour
    final nextQuarter = ((now.minute ~/ 15) + 1) * 15;
    int hour = now.hour + (nextQuarter >= 60 ? 1 : 0);
    int minute = nextQuarter % 60;
    _selectedTime = TimeOfDay(hour: hour, minute: minute);

    _servicesFuture = _barbershopService.getAllServices();
    _barbermenFuture = _barbershopService.getBarbermenByShop(widget.barbershop.id);
    Intl.defaultLocale = 'id_ID';
  }

  // ---------- Logic ----------
  void _updateEstimatedFinishTime() {
    if (_selectedBarberman != null && _selectedServices.isNotEmpty) {
      final start = DateTime(_selectedDate.year, _selectedDate.month,
          _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
      final minutes = _totalDuration;
      setState(() {
        _estimatedFinishTime = start.add(Duration(minutes: minutes));
      });
      _checkSlotAvailability();
    } else {
      setState(() {
        _estimatedFinishTime = null;
        _slotAvailabilityMessage = '';
        _isSlotAvailable = false;
      });
    }
  }

  Future<void> _checkSlotAvailability() async {
    if (_selectedBarberman == null || _selectedServices.isEmpty) return;
    setState(() => _slotAvailabilityMessage = 'Mengecek ketersediaan slot...');
    final booking = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedTime.hour, _selectedTime.minute);

    try {
      final ok = await _checkSlotAvailable(
        barbershopId: widget.barbershop.id,
        barbermanId: _selectedBarberman!.id,
        bookingTime: booking,
        serviceIds: _selectedServices.map((s) => s.id).toList(),
      );
      if (!mounted) return;
      setState(() {
        _isSlotAvailable = ok;
        _slotAvailabilityMessage =
            ok ? 'Slot tersedia' : 'Slot bentrok dengan booking lain';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSlotAvailable = false;
        _slotAvailabilityMessage = 'Gagal memeriksa slot';
      });
    }
  }

  // helper untuk check slot availability
  Future<bool> _checkSlotAvailable({
    required String barbershopId,
    required String barbermanId,
    required DateTime bookingTime,
    required List<String> serviceIds,
  }) =>
      _queueService.isSlotAvailable(
        barbershopId: barbershopId,
        barbermanId: barbermanId,
        bookingTime: bookingTime,
        serviceIds: serviceIds,
      );

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kBrownAccent,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _updateEstimatedFinishTime();
    }
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: kBrownAccent,
              onPrimary: Colors.black,
              surface: Colors.black,
              onSurface: Colors.white,
            ),
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E1E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      final open = widget.barbershop.openHour;
      final close = widget.barbershop.closeHour;
      if (picked.hour < open || picked.hour >= close) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Pilih waktu antara $open:00 - $close:00')));
        return;
      }
      // Cegah memilih waktu yang sudah lewat pada hari ini
      final now = DateTime.now();
      final isToday = _selectedDate.year == now.year &&
          _selectedDate.month == now.month &&
          _selectedDate.day == now.day;
      if (isToday) {
        final pickedDateTime = DateTime(_selectedDate.year, _selectedDate.month,
            _selectedDate.day, picked.hour, picked.minute);
        if (pickedDateTime.isBefore(now)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Tidak bisa memilih waktu yang sudah lewat')));
          return;
        }
      }
      setState(() => _selectedTime = picked);
      _updateEstimatedFinishTime();
    }
  }

  Future<void> _processBooking() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_selectedServices.isEmpty) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Pilih minimal satu layanan'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    if (_selectedBarberman == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Pilih barberman'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    if (!_isSlotAvailable) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Slot tidak tersedia, silakan pilih waktu/barberman lain'),
          backgroundColor: Colors.orangeAccent));
      return;
    }
    if (_auth.currentUser == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Silakan login untuk melanjutkan booking'),
          backgroundColor: Colors.redAccent));
      return;
    }

    setState(() => _isLoading = true);
    final bookingDate = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    final customerId = _auth.currentUser!.uid;

    // Validasi akhir: booking time tidak boleh masa lalu
    if (bookingDate.isBefore(DateTime.now())) {
      if (mounted) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Waktu booking sudah lewat, pilih waktu lain'),
            backgroundColor: Colors.orangeAccent));
        setState(() => _isLoading = false);
      }
      return;
    }

    final String newOrderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'barbershop_id': widget.barbershop.id,
      'customer_id': customerId,
      'barberman_id': _selectedBarberman!.id,
      'service_ids': _selectedServices.map((s) => s.id).toList(),
      'total_price': _totalPrice,
      'estimated_duration': _totalDuration,
      'booking_time': Timestamp.fromDate(bookingDate),
      'status': 'waiting',
      'order_id': newOrderId,
    };

    try {
      // await createQueue without storing unused local variable
      await _queueService.createQueue(payload);

      if (!mounted) return;

      final paymentResult = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            orderId: newOrderId,
            totalPrice: _totalPrice,
            barbershopId: widget.barbershop.id,
            barbermanId: _selectedBarberman!.id,
            bookingTime: bookingDate,
            serviceIds: _selectedServices.map((s) => s.id).toList(),
          ),
        ),
      );

      if (paymentResult == true && mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(
          content: Text('Gagal membuat antrean: ${e.toString()}'),
          backgroundColor: Colors.redAccent));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottomInset = media.viewInsets.bottom;
    final safeBottom = media.padding.bottom;

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        elevation: 0,
        title: Text(widget.barbershop.name,
            style: const TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(20, 18, 20, kBottomBuffer),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _shopHeader(),
            const SizedBox(height: 24),
            _sectionTitle('Pilih Layanan'),
            const SizedBox(height: 12),

            // --- SERVICES ---
            SizedBox(
              height: 200,
              child: FutureBuilder<List<Service>>(
                future: _servicesFuture,
                builder: (ctx, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(color: kBrownAccent));
                  }
                  if (snap.hasError) {
                    return const Center(
                        child: Text('Gagal memuat layanan',
                            style: TextStyle(color: Colors.white70)));
                  }

                  final allServices = snap.data ?? [];
                  final shopServiceIds = widget.barbershop.services.toSet();
                  final services = (shopServiceIds.isEmpty)
                      ? allServices
                      : allServices.where((s) => shopServiceIds.contains(s.id)).toList();

                  if (services.isEmpty) {
                    return const Center(
                        child: Text('Belum ada layanan untuk barbershop ini',
                            style: TextStyle(color: Colors.white70)));
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    itemCount: services.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      mainAxisExtent: 80,
                    ),
                    itemBuilder: (c, i) {
                      final s = services[i];
                      final selected = _selectedServices.any((e) => e.id == s.id);
                      return _buildServiceTile(s, selected);
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 24),
            _sectionTitle('Hair Specialist'),
            const SizedBox(height: 12),

            // --- BARBERMEN ---
            FutureBuilder<List<Barberman>>(
              future: _barbermenFuture,
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                      height: 150,
                      child: Center(
                          child: CircularProgressIndicator(color: kBrownAccent)));
                }
                if (snap.hasError || (snap.data?.isEmpty ?? true)) {
                  return const SizedBox(
                      height: 150,
                      child: Center(
                          child: Text('Barberman tidak tersedia',
                              style: TextStyle(color: Colors.white70))));
                }
                final barbermen = snap.data!;
                return SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: barbermen.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (c, i) {
                      final b = barbermen[i];
                      final isSelected = _selectedBarberman?.id == b.id;
                      return _buildBarbermanTile(b, isSelected);
                    },
                  ),
                );
              },
            ),

            const SizedBox(height: 24),
            _sectionTitle('Tanggal & Waktu'),
            const SizedBox(height: 12),

            // --- DATE/TIME ---
            _buildDateTimePickers(),
            const SizedBox(height: 16),
            if (_slotAvailabilityMessage.isNotEmpty) _slotBox(),
            const SizedBox(height: 10),
            if (_estimatedFinishTime != null) _estimCard(),
            const SizedBox(height: 18),
            _notesBox(),
          ]),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: _bottomBar(safeBottomPadding: safeBottom),
      ),
    );
  }

  // ---------- Small Widgets ----------
  Widget _shopHeader() {
    final address = widget.barbershop.addres;
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: widget.barbershop.imageUrl,
          width: 84,
          height: 84,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
              width: 84,
              height: 84,
              color: Colors.grey[900],
              child: const Icon(Icons.storefront,
                  color: Colors.white54, size: 36)),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.barbershop.name,
              style: const TextStyle(
                  color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Text(address,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.star, color: Colors.amber, size: 16),
            const SizedBox(width: 6),
            Text(widget.barbershop.rating.toStringAsFixed(1),
                style: const TextStyle(color: Colors.white70)),
            const SizedBox(width: 12),
            const Icon(Icons.access_time, color: Colors.white54, size: 16),
            const SizedBox(width: 6),
            Text(
                '${widget.barbershop.openHour}:00 - ${widget.barbershop.closeHour}:00',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ]),
        ]),
      )
    ]);
  }

  Widget _sectionTitle(String t) => Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(t,
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)));

  Widget _buildServiceTile(Service s, bool selected) {
    return InkWell(
      onTap: () {
        setState(() {
          final isSel = _selectedServices.any((e) => e.id == s.id);
          if (isSel) {
            _selectedServices.removeWhere((e) => e.id == s.id);
          } else {
            _selectedServices.add(s);
          }
          _updateEstimatedFinishTime();
        });
      },
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color.fromRGBO(195,164,123,0.18) : const Color(0xFF171717),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? kBrownAccent : Colors.grey.shade800,
              width: 1.0),
        ),
        child: Row(children: [
          Checkbox(
            value: selected,
            onChanged: (v) {
              setState(() {
                final isSel = _selectedServices.any((e) => e.id == s.id);
                if (isSel) {
                  _selectedServices.removeWhere((e) => e.id == s.id);
                } else {
                  _selectedServices.add(s);
                }
                _updateEstimatedFinishTime();
              });
            },
            activeColor: kBrownAccent,
            checkColor: Colors.black,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name,
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                      '${_currencyFormat.format(s.price)} • ${s.defaultDuration}m',
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ]),
          ),
        ]),
      ),
    );
  }

  Widget _buildBarbermanTile(Barberman b, bool selected) {
    final avatarLetter = (b.name.isNotEmpty) ? b.name[0].toUpperCase() : '?';
    return GestureDetector(
      onTap: () {
        setState(() => _selectedBarberman = b);
        _updateEstimatedFinishTime();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 110,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color:
              selected ? const Color.fromRGBO(195,164,123,0.18) : const Color(0xFF121212),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: selected ? kBrownAccent : Colors.grey.shade800,
              width: 1.0),
        ),
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade900,
            child: ClipOval(
              child: CachedNetworkImage(
                imageUrl: b.imageUrl ??
                    "https://placehold.co/100x100/FFFFFF/000000?text=$avatarLetter",
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                placeholder: (_, __) =>
                    const Icon(Icons.person, color: Colors.white54, size: 28),
                errorWidget: (_, __, ___) => Center(
                    child: Text(avatarLetter,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 20))),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: Text(
              b.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 4),
          Text('${b.avgDuration.toInt()}m avg',
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildDateTimePickers() {
    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: _pickDate,
          icon: const Icon(Icons.calendar_today, size: 18, color: kBrownAccent),
          label: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_dateFormat.format(_selectedDate),
                  style: const TextStyle(color: Colors.white)),
              const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ],
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            side: BorderSide(color: Colors.grey.shade800),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickTime,
          icon: const Icon(Icons.access_time, size: 18, color: kBrownAccent),
          label: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_selectedTime.format(context),
                  style: const TextStyle(color: Colors.white)),
              const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ],
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            side: BorderSide(color: Colors.grey.shade800),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _slotBox() {
    final color = _isSlotAvailable ? Colors.greenAccent : Colors.orangeAccent;
    final bg = _isSlotAvailable ? const Color.fromRGBO(0,128,0,0.08) : const Color.fromRGBO(255,165,0,0.08);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: bg,
          border: Border.all(color: color)),
      child: Text(_slotAvailabilityMessage,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _estimCard() {
    final start = DateTime(_selectedDate.year, _selectedDate.month,
        _selectedDate.day, _selectedTime.hour, _selectedTime.minute);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF171717),
          border: Border.all(color: Colors.grey.shade800)),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Estimasi selesai:',
            style: TextStyle(color: Colors.white70)),
        Text(
            '${_timeFormat.format(start)} - ${_timeFormat.format(_estimatedFinishTime!)}',
            style: const TextStyle(
                color: kBrownAccent,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
      ]),
    );
  }

  Widget _notesBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: const Color(0xFF171717)),
      child: const Row(children: [
        Icon(Icons.info_outline, color: Colors.white38, size: 20),
        SizedBox(width: 10),
        Expanded(
          child: Text(
              'Datang 5 menit lebih awal. Keterlambatan dapat membatalkan booking.',
              style: TextStyle(color: Colors.white54, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _bottomBar({required double safeBottomPadding}) {
    final est = _totalDuration > 0 ? 'Est ${_totalDuration}m' : 'Est 0m';
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
          20, 16, 20, 16 + safeBottomPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total',
                  style: const TextStyle(color: Colors.white54, fontSize: 13)),
              Text(_currencyFormat.format(_totalPrice),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${_selectedServices.length} layanan • $est',
              style: const TextStyle(color: Colors.white54, fontSize: 12)),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
                  (_isLoading || !_isSlotAvailable) ? null : _processBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                disabledBackgroundColor: Colors.grey.shade700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black))
                  : const Text('BOOK NOW',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          )
        ],
      ),
    );
  }
}
