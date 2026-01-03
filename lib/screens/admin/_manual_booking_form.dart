import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

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
  // Services
  final BarbershopService _bs = BarbershopService();

  // Theme
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Color(0xFF0F0F0F);
  static const Color kCardBg = Color(0xFF1A1A1A);

  // State: Wizard Steps
  int _currentStep = 0; // 0: Services, 1: Specialist, 2: Schedule

  // Data
  List<Service> _availableServices = [];
  final List<Service> _selectedServices = [];
  bool _isPremiumChoice = false; // Admin picks specific barber for customer
  Barberman? _selectedBarberman; 
  Barberman? _autoBarberman; 
  
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _isLoading = false;
  bool _submitting = false;
  bool _isCheckingAvailability = false;
  String? _availabilityError;

  // Totals
  int get _servicesPrice => _selectedServices.fold(0, (prev, s) => prev + s.price.toInt());
  int get _selectionFee => _isPremiumChoice ? widget.barbershop.barberSelectionFee : 0;
  int get _totalPrice => _servicesPrice + _selectionFee;
  int get _totalDuration => _selectedServices.fold(0, (prev, s) => prev + s.defaultDuration);

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    try {
      final all = await _bs.getAllServices();
      final shopSet = widget.barbershop.services.toSet();
      _availableServices = all.where((s) => shopSet.contains(s.id)).toList();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isShopOpenOn(DateTime date) {
    if (widget.barbershop.weeklyHolidays.contains(date.weekday % 7)) return false;
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    if (widget.barbershop.specificHolidays.contains(dateStr)) return false;
    return true;
  }

  Future<void> _checkBarberAvailability() async {
    if (_selectedTime == null) return;
    
    setState(() {
      _isCheckingAvailability = true;
      _availabilityError = null;
    });

    final bookingDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );

    try {
      if (_isPremiumChoice) {
        if (_selectedBarberman == null) throw "Pilih barber terlebih dahulu";
        final isAvailable = await widget.queueService.isSlotAvailable(
          barbershopId: widget.barbershop.id,
          barbermanId: _selectedBarberman!.id,
          bookingTime: bookingDateTime,
          serviceIds: _selectedServices.map((s) => s.id).toList(),
        );
        if (!isAvailable) throw "Barber sudah ada jadwal di jam ini";
      } else {
        final fairId = await widget.queueService.getFairAvailableBarberman(
          barbershopId: widget.barbershop.id,
          bookingTime: bookingDateTime,
          serviceIds: _selectedServices.map((s) => s.id).toList(),
        );
        if (fairId == null) throw "Tidak ada barber tersedia jam ini";
        _autoBarberman = await _bs.getBarbermanById(fairId);
      }
    } catch (e) {
      setState(() => _availabilityError = e.toString());
    } finally {
      setState(() => _isCheckingAvailability = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedServices.isEmpty) {
      _showSnack("Pilih layanan");
      return;
    }
    if (_currentStep == 1 && _isPremiumChoice && _selectedBarberman == null) {
      _showSnack("Pilih barber spesifik");
      return;
    }
    setState(() => _currentStep++);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kSurface,
      child: Column(
        children: [
          _buildStepIndicator(),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildCurrentStep())),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30),
      child: Row(
        children: [
          _indicatorCircle(0, "Layanan"),
          _indicatorLine(0),
          _indicatorCircle(1, "Barber"),
          _indicatorLine(1),
          _indicatorCircle(2, "Jadwal"),
        ],
      ),
    );
  }

  Widget _indicatorCircle(int idx, String label) {
    bool active = _currentStep >= idx;
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? kBrownAccent : Colors.white10,
          child: Text("${idx + 1}", style: TextStyle(color: active ? Colors.black : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? kBrownAccent : Colors.white24, fontSize: 10)),
      ],
    );
  }

  Widget _indicatorLine(int idx) => Expanded(child: Divider(color: _currentStep > idx ? kBrownAccent : Colors.white10, thickness: 2, indent: 10, endIndent: 10));

  Widget _buildCurrentStep() {
    switch (_currentStep) {
      case 0: return _buildServiceStep();
      case 1: return _buildBarberStep();
      case 2: return _buildScheduleStep();
      default: return const SizedBox();
    }
  }

  Widget _buildServiceStep() {
    if (_availableServices.isEmpty && !_isLoading) return const Center(child: Text("Tidak ada layanan tersedia", style: TextStyle(color: Colors.white54)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pilih Layanan Offline", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        ..._availableServices.map((s) {
          bool isSelected = _selectedServices.any((item) => item.id == s.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => setState(() => isSelected ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s)),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isSelected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent)),
                child: Row(
                  children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      Text("Rp ${s.price.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
                    ])),
                    Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? kBrownAccent : Colors.white10),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildBarberStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Pilihan Hairstylist", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _choiceCard(Icons.shuffle, "Acak / Otomatis", "System pilih barber tersedia (Fairness)", !_isPremiumChoice, () => setState(() => _isPremiumChoice = false)),
        const SizedBox(height: 12),
        _choiceCard(Icons.person_search, "Request Barber Spesifik", "Customer request barber tertentu (+Rp ${widget.barbershop.barberSelectionFee})", _isPremiumChoice, () => setState(() => _isPremiumChoice = true)),
        if (_isPremiumChoice) ...[
          const SizedBox(height: 30),
          _buildBarberList(),
        ]
      ],
    );
  }

  Widget _choiceCard(IconData icon, String title, String sub, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: selected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? kBrownAccent : Colors.transparent)),
        child: Row(
          children: [
            Icon(icon, color: selected ? kBrownAccent : Colors.white24, size: 28),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: TextStyle(color: selected ? kBrownAccent : Colors.white, fontWeight: FontWeight.bold)),
              Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 11)),
            ])),
            if (selected) const Icon(Icons.check_circle, color: kBrownAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberList() {
    return FutureBuilder<List<Barberman>>(
      future: _bs.getBarbermenByShop(widget.barbershop.id),
      builder: (context, snap) {
        if (!snap.hasData) return const LinearProgressIndicator(color: kBrownAccent);
        final barbers = snap.data!.where((b) => b.isActive).toList();
        return Wrap(
          spacing: 12, runSpacing: 12,
          children: barbers.map((b) {
            bool sel = _selectedBarberman?.id == b.id;
            return InkWell(
              onTap: () => setState(() => _selectedBarberman = b),
              child: Column(
                children: [
                  CircleAvatar(radius: 30, backgroundColor: sel ? kBrownAccent : kCardBg, child: const Icon(Icons.person, color: Colors.white24)),
                  const SizedBox(height: 4),
                  Text(b.name, style: TextStyle(color: sel ? kBrownAccent : Colors.white70, fontSize: 11)),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Waktu Pelayanan", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        _buildDateGrid(),
        const SizedBox(height: 24),
        _buildTimeGrid(),
        if (_availabilityError != null) Padding(padding: const EdgeInsets.only(top: 20), child: Text(_availabilityError!, style: const TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  Widget _buildDateGrid() {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, i) {
          final date = DateTime.now().add(Duration(days: i));
          bool open = _isShopOpenOn(date);
          bool sel = _selectedDate.day == date.day;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: open ? () => setState(() { _selectedDate = date; _selectedTime = null; _availabilityError = null; }) : null,
              child: Container(
                width: 60,
                decoration: BoxDecoration(color: sel ? kBrownAccent : (open ? kCardBg : Colors.transparent), borderRadius: BorderRadius.circular(12)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(DateFormat('EEE').format(date), style: TextStyle(color: sel ? Colors.black : Colors.white38, fontSize: 10)),
                  Text("${date.day}", style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeGrid() {
    final List<TimeOfDay> times = [];
    for (int h = widget.barbershop.openHour; h < widget.barbershop.closeHour; h++) {
      times.add(TimeOfDay(hour: h, minute: 0));
      times.add(TimeOfDay(hour: h, minute: 30));
    }
    return GridView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2),
      itemCount: times.length,
      itemBuilder: (context, i) {
        final t = times[i];
        bool sel = _selectedTime == t;
        return InkWell(
          onTap: () { setState(() { _selectedTime = t; _availabilityError = null; }); _checkBarberAvailability(); },
          child: Container(
            decoration: BoxDecoration(color: sel ? kBrownAccent : kCardBg, borderRadius: BorderRadius.circular(8), border: Border.all(color: sel ? kBrownAccent : Colors.white10)),
            alignment: Alignment.center,
            child: Text("${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}", style: TextStyle(color: sel ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }

  Widget _buildBottomSummary() {
    bool canGo = (_currentStep == 0 && _selectedServices.isNotEmpty) || (_currentStep == 1 && (!_isPremiumChoice || _selectedBarberman != null));
    bool isLast = _currentStep == 2;
    if (isLast && (_selectedTime == null || _availabilityError != null || _isCheckingAvailability)) canGo = false;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: kCardBg, border: Border(top: BorderSide(color: Colors.white10))),
      child: Row(
        children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text("Total (Tunai)", style: TextStyle(color: Colors.white54, fontSize: 12)),
            Text("Rp ${NumberFormat('#,###').format(_totalPrice)}", style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold)),
          ])),
          ElevatedButton(
            onPressed: canGo ? (isLast ? _submit : _nextStep) : null,
            style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15)),
            child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(isLast ? "BOOKING" : "LANJUT"),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final bookingDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);
      final barberId = _isPremiumChoice ? _selectedBarberman!.id : _autoBarberman!.id;
      final payload = {
        'barbershop_id': widget.barbershop.id,
        'barberman_id': barberId,
        'customer_id': 'WALKIN_${DateTime.now().millisecondsSinceEpoch}',
        'customer_name': 'Walk-in Customer',
        'customer_is_manual': true,
        'service_ids': _selectedServices.map((s) => s.id).toList(),
        'total_price': _totalPrice,
        'barber_selection_fee': _selectionFee,
        'paid_barber_selection': _isPremiumChoice,
        'estimated_duration': _totalDuration,
        'booking_time': Timestamp.fromDate(bookingDateTime),
        'status': 'booked',
        'payment_method': 'cash_offline',
      };
      await widget.queueService.createQueue(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking offline berhasil!'), backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      _showSnack("Error: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
