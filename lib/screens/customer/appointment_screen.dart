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
import 'package:geges_smartbarber/screens/customer/payment_screen.dart';

class AppointmentScreen extends StatefulWidget {
  final Barbershop barbershop;
  final BarbershopService? barbershopService;
  final QueueService? queueService;
  final String? testUserId;
  const AppointmentScreen({super.key, required this.barbershop, this.barbershopService, this.queueService, this.testUserId});
  @override State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  late BarbershopService _barbershopService;
  late final QueueService _queueService;
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Color(0xFF0F0F0F);
  static const Color kCardBg = Color(0xFF1A1A1A);

  int _currentStep = 0; 
  final List<Service> _selectedServices = [];
  bool _isPremiumChoice = false; 
  Barberman? _selectedBarberman; 
  Barberman? _autoBarberman; 
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isLoading = false;
  bool _isCheckingAvailability = false;
  bool _isFetchingSlots = false;
  String? _availabilityError;
  List<DateTimeRange> _busySlots = []; 

  int get _servicesPrice => _selectedServices.fold(0, (prev, s) => prev + s.price.toInt());
  int get _selectionFee => _isPremiumChoice ? widget.barbershop.barberSelectionFee : 0;
  int get _totalPrice => _servicesPrice + _selectionFee;
  int get _totalDuration => _selectedServices.fold(0, (prev, s) => prev + s.defaultDuration);

  @override void initState() { super.initState(); _barbershopService = widget.barbershopService ?? BarbershopService(); _queueService = widget.queueService ?? QueueService(); _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); _fetchBusySlots(); }

  Future<void> _fetchBusySlots() async {
    if (!mounted) return;
    setState(() { _busySlots = []; _isFetchingSlots = true; });
    try {
      List<DateTimeRange> slots = [];
      if (_isPremiumChoice && _selectedBarberman != null) {
        slots = await _queueService.getBarberBusyTimeRanges(_selectedBarberman!.id, _selectedDate);
      // ignore: curly_braces_in_flow_control_structures
      } else if (!_isPremiumChoice) slots = await _queueService.getShopBusySlots(barbershopId: widget.barbershop.id, date: _selectedDate);
      if (mounted) setState(() { _busySlots = slots; _isFetchingSlots = false; });
    } catch (e) { if (mounted) setState(() => _isFetchingSlots = false); }
  }

  bool _isShopOpenOn(DateTime date) {
    if (widget.barbershop.weeklyHolidays.contains(date.weekday % 7)) return false;
    if (widget.barbershop.specificHolidays.contains(DateFormat('yyyy-MM-dd').format(date))) return false;
    return true;
  }

  Future<void> _checkBarberAvailability() async {
    if (_selectedTime == null) return;
    setState(() { _isCheckingAvailability = true; _availabilityError = null; });
    final bookingDateTime = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);
    try {
      if (_isPremiumChoice) {
        if (_selectedBarberman == null) throw "Pilih barber terlebih dahulu";
        final isAvailable = await _queueService.isSlotAvailable(barbershopId: widget.barbershop.id, barbermanId: _selectedBarberman!.id, bookingTime: bookingDateTime, serviceIds: _selectedServices.map((s) => s.id).toList());
        if (!isAvailable) throw "Barber tersebut sudah ada jadwal di jam ini";
      } else {
        final fairId = await _queueService.getFairAvailableBarberman(barbershopId: widget.barbershop.id, bookingTime: bookingDateTime, serviceIds: _selectedServices.map((s) => s.id).toList());
        if (fairId == null) throw "Tidak ada hairstylist tersedia jam ini. Coba jam lain.";
        final b = await _barbershopService.getBarbermanById(fairId);
        setState(() => _autoBarberman = b);
      }
    } catch (e) { setState(() => _availabilityError = e.toString()); } finally { setState(() => _isCheckingAvailability = false); }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      if (_currentStep == 0 && _selectedServices.isEmpty) {
        _showSnack("Pilih minimal satu layanan");
        return;
      }
      if (_currentStep == 1 && _isPremiumChoice && _selectedBarberman == null) {
        _showSnack("Silakan pilih barber favorit Anda");
        return;
      }
      setState(() => _currentStep++);
      if (_currentStep == 2) {
        _fetchBusySlots();
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }
  void _showSnack(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override Widget build(BuildContext context) {
    // 1. BLOCKING LOGIC: If shop is closed, show "Shop Closed" screen
    if (!widget.barbershop.isOpen) {
      return Scaffold(
        backgroundColor: kSurface,
        appBar: AppBar(
          backgroundColor: kSurface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20), 
            onPressed: () => Navigator.pop(context)
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.storefront, size: 64, color: Colors.redAccent),
              ),
              const SizedBox(height: 24),
              Text(
                "${widget.barbershop.name} Sedang Tutup",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                "Maaf, barbershop ini sedang tidak menerima pesanan.\nSilakan cek kembali nanti.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 32),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text("Kembali ke Home", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    // 2. NORMAL FLOW
    return PopScope(canPop: false, onPopInvokedWithResult: (didPop, result) { if (didPop) return; if (_currentStep > 0) {
      _prevStep();
    } else {
      Navigator.pop(context);
    } },
      child: Scaffold(backgroundColor: kSurface, appBar: AppBar(backgroundColor: kSurface, title: Text(widget.barbershop.name, style: const TextStyle(fontWeight: FontWeight.bold)), elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => _currentStep > 0 ? _prevStep() : Navigator.pop(context))),
        body: Column(children: [_buildProgressHeader(), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildCurrentStepView())), _buildBottomSummary()])));
  }

  Widget _buildProgressHeader() { return Container(padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40), child: Row(children: [_stepDot(0, "Layanan"), _stepLine(0), _stepDot(1, "Barber"), _stepLine(1), _stepDot(2, "Jadwal")])); }
  Widget _stepDot(int index, String label) { bool active = _currentStep >= index; return Column(children: [CircleAvatar(radius: 12, backgroundColor: active ? kBrownAccent : Colors.grey[800], child: Text("${index + 1}", style: TextStyle(color: active ? Colors.black : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? kBrownAccent : Colors.white24, fontSize: 10))]); }
  Widget _stepLine(int index) { bool active = _currentStep > index; return Expanded(child: Divider(color: active ? kBrownAccent : Colors.grey[800], thickness: 2, indent: 8, endIndent: 8)); }
  Widget _buildCurrentStepView() { switch (_currentStep) { case 0: return _buildServiceStep(); case 1: return _buildBarberStep(); case 2: return _buildScheduleStep(); default: return const SizedBox(); } }

  Widget _buildServiceStep() {
    return FutureBuilder<List<Service>>(future: _barbershopService.getAllServices(), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
      final shopServices = snap.data!.where((s) => widget.barbershop.services.contains(s.id)).toList();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Pilih Layanan", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text("Anda bisa memilih lebih dari satu layanan", style: TextStyle(color: Colors.white54)), const SizedBox(height: 24), ...shopServices.map((s) => _serviceCard(s))]);
    });
  }

  Widget _serviceCard(Service s) {
    bool isSelected = _selectedServices.any((item) => item.id == s.id);
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () { setState(() { isSelected ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s); }); }, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: isSelected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text("${s.defaultDuration} mnt • Rp ${s.price.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 13))])), Checkbox(value: isSelected, onChanged: (_) { setState(() { isSelected ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s); }); }, activeColor: kBrownAccent, checkColor: Colors.black)]))));
  }

  Widget _buildBarberStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Siapa yang mencukur?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
      _choiceCard(icon: Icons.auto_awesome, title: "Dipilihkan Sistem (Adil & Cepat)", subtitle: "Sistem akan mencarikan barber terbaik yang tersedia untuk Anda.", isSelected: !_isPremiumChoice, onTap: () { setState(() { _isPremiumChoice = false; _selectedBarberman = null; _availabilityError = null; }); _fetchBusySlots(); }), const SizedBox(height: 16),
      _choiceCard(icon: Icons.stars, title: "Pilih Barber Favorit", subtitle: "Pilih barber tertentu yang sudah Anda kenal (+ Rp ${widget.barbershop.barberSelectionFee})", isSelected: _isPremiumChoice, onTap: () { setState(() { _isPremiumChoice = true; _availabilityError = null; }); _fetchBusySlots(); }),
      if (_isPremiumChoice) ...[const SizedBox(height: 32), const Text("Daftar Specialist", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 16), _buildBarberList()]
    ]);
  }

  Widget _choiceCard({required IconData icon, required String title, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: isSelected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent)), child: Row(children: [Icon(icon, color: isSelected ? kBrownAccent : Colors.white24, size: 32), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(color: isSelected ? kBrownAccent : Colors.white, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12))])), if (isSelected) const Icon(Icons.check_circle, color: kBrownAccent, size: 20)])));
  }

  Widget _buildBarberList() {
    return FutureBuilder<List<Barberman>>(future: _barbershopService.getBarbermenByShop(widget.barbershop.id), builder: (context, snap) {
      if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
      final activeBarbers = snap.data!.where((b) => b.isActive).toList();
      return SizedBox(height: 120, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: activeBarbers.length, itemBuilder: (context, i) { final b = activeBarbers[i]; bool isSelected = _selectedBarberman?.id == b.id; return Padding(padding: const EdgeInsets.only(right: 12), child: InkWell(onTap: () { setState(() => _selectedBarberman = b); _fetchBusySlots(); }, child: Column(children: [Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent, width: 2), image: b.imageUrl != null ? DecorationImage(image: CachedNetworkImageProvider(b.imageUrl!), fit: BoxFit.cover) : null, color: Colors.grey[900]), child: b.imageUrl == null ? const Icon(Icons.person, color: Colors.white24) : null), const SizedBox(height: 8), Text(b.name, style: TextStyle(color: isSelected ? kBrownAccent : Colors.white70, fontSize: 12))]))); }));
    });
  }

  Widget _buildScheduleStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Tentukan Jadwal", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 24),
      const Text("Pilih Hari", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 12), _buildDateRow(), const SizedBox(height: 32),
      const Text("Pilih Jam", style: TextStyle(color: Colors.white70, fontSize: 14)), const SizedBox(height: 12), _buildTimeGrid(),
      if (_availabilityError != null) ...[const SizedBox(height: 24), Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.error_outline, color: Colors.redAccent), const SizedBox(width: 12), Expanded(child: Text(_availabilityError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)))]))]
    ]);
  }

  Widget _buildDateRow() {
    return SizedBox(height: 90, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 14, itemBuilder: (context, i) {
      final date = DateTime.now().add(Duration(days: i)); 
      bool isOpen = _isShopOpenOn(date);
      if (isOpen && _isPremiumChoice && _selectedBarberman != null) { 
        final b = _selectedBarberman!; 
        final dayName = DateFormat('EEEE', 'en_US').format(date).toLowerCase(); 
        if (b.offDays != null && b.offDays!.any((d) => d.name == dayName)) isOpen = false; 
        if (b.specificOffDays.contains(DateFormat('yyyy-MM-dd').format(date))) isOpen = false; 
      }
      bool isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
      return Padding(padding: const EdgeInsets.only(right: 10), child: InkWell(onTap: isOpen ? () { setState(() { _selectedDate = date; _selectedTime = null; _availabilityError = null; }); _fetchBusySlots(); } : null, child: Container(width: 65, decoration: BoxDecoration(color: isSelected ? kBrownAccent : (isOpen ? kCardBg : Colors.black26), borderRadius: BorderRadius.circular(16)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('EEE').format(date), style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontSize: 12)), const SizedBox(height: 4), Text("${date.day}", style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), if (!isOpen) const Text("LIBUR", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold))]))));
    }));
  }

  Widget _buildTimeGrid() {
    final List<TimeOfDay> times = [];
    for (int h = widget.barbershop.openHour; h < widget.barbershop.closeHour; h++) { times.add(TimeOfDay(hour: h, minute: 0)); times.add(TimeOfDay(hour: h, minute: 30)); }
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2), itemCount: times.length, itemBuilder: (context, i) {
      if (_isFetchingSlots) return Container(decoration: BoxDecoration(color: kCardBg, borderRadius: BorderRadius.circular(8)), alignment: Alignment.center, child: const SizedBox(height: 10, width: 10, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white24)));
      final t = times[i]; bool isSelected = _selectedTime == t; bool isPast = false;
      if (_selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month && _selectedDate.day == DateTime.now().day) { if (t.hour < DateTime.now().hour || (t.hour == DateTime.now().hour && t.minute < DateTime.now().minute)) isPast = true; }
      bool isBusy = false;
      if (!isPast && _busySlots.isNotEmpty) {
        final slotStart = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, t.hour, t.minute);
        final slotEnd = slotStart.add(const Duration(minutes: 30));
        
        for (var range in _busySlots) {
          // Strict overlap logic with 1-second tolerance
          if (slotStart.isBefore(range.end.subtract(const Duration(seconds: 1))) && 
              slotEnd.isAfter(range.start.add(const Duration(seconds: 1)))) {
            isBusy = true;
            break;
          }
        }
      }
      bool isDisabled = isPast || isBusy;
      
      return InkWell(
        onTap: isDisabled ? null : () { 
          setState(() { _selectedTime = t; _availabilityError = null; }); 
          _checkBarberAvailability(); 
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? kBrownAccent : (isDisabled ? Colors.white.withValues(alpha: 0.05) : kCardBg),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent),
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text(
                "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}", 
                style: TextStyle(
                  color: isSelected ? Colors.black : (isDisabled ? Colors.white24 : Colors.white), 
                  fontWeight: FontWeight.bold,
                  decoration: isDisabled ? TextDecoration.lineThrough : null,
                  decorationColor: Colors.white24,
                  decorationThickness: 2,
                )
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildBottomSummary() {
    bool canProceed = false; String btnText = "LANJUT";
    if (_currentStep == 0 && _selectedServices.isNotEmpty) canProceed = true;
    if (_currentStep == 1) { if (!_isPremiumChoice) canProceed = true; if (_isPremiumChoice && _selectedBarberman != null) canProceed = true; }
    if (_currentStep == 2) { if (_selectedTime != null && _availabilityError == null && !_isCheckingAvailability) { canProceed = true; btnText = "BOOK NOW"; } }
    return Container(padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom), decoration: BoxDecoration(color: kCardBg, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))), child: Row(children: [Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Total Estimasi", style: TextStyle(color: Colors.white54, fontSize: 12)), Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_totalPrice), style: const TextStyle(color: kBrownAccent, fontSize: 20, fontWeight: FontWeight.bold))])), SizedBox(width: 140, height: 50, child: ElevatedButton(onPressed: (canProceed && !_isLoading) ? (_currentStep == 2 ? _processBooking : _nextStep) : null, style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, disabledBackgroundColor: Colors.white10, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text(btnText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))))]));
  }

  Future<void> _processBooking() async {
    final bdt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);
    final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(backgroundColor: kCardBg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), title: const Text('Konfirmasi Booking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [_confirmRow("Tanggal", DateFormat('dd MMM yyyy').format(bdt)), _confirmRow("Jam", DateFormat('HH:mm').format(bdt)), _confirmRow("Barber", _isPremiumChoice ? _selectedBarberman?.name ?? '-' : 'Sistem Acak'), const SizedBox(height: 8), const Divider(color: Colors.white24), const SizedBox(height: 8), _confirmRow("Total Biaya", NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_totalPrice), isBold: true, color: kBrownAccent)]), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal', style: TextStyle(color: Colors.white54))), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent), child: const Text('Booking Sekarang', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)))]));
    if (confirm != true) return;
    setState(() => _isLoading = true);
    final customerId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
    final barberId = _isPremiumChoice ? _selectedBarberman!.id : _autoBarberman!.id;
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
    final payload = {'barbershop_id': widget.barbershop.id, 'customer_id': customerId, 'barberman_id': barberId, 'service_ids': _selectedServices.map((s) => s.id).toList(), 'total_price': _totalPrice, 'barber_selection_fee': _selectionFee, 'paid_barber_selection': _isPremiumChoice, 'is_auto_assigned': !_isPremiumChoice, 'estimated_duration': _totalDuration, 'booking_time': Timestamp.fromDate(bdt), 'status': 'awaiting_payment', 'request_status': 'approved', 'payment_deadline': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))), 'order_id': orderId};
    try { await _queueService.createQueue(payload); if (!mounted) return; Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (c) => PaymentScreen(orderId: orderId, totalPrice: _totalPrice, barbershopId: widget.barbershop.id, barbermanId: barberId, bookingTime: bdt, paymentDeadline: DateTime.now().add(const Duration(minutes: 15))))); } catch (e) { _showSnack("Gagal: $e"); } finally { setState(() => _isLoading = false); }
  }
  Widget _confirmRow(String l, String v, {bool isBold = false, Color color = Colors.white}) => Padding(padding: const EdgeInsets.only(bottom: 4.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: Colors.white70)), Text(v, style: TextStyle(color: color, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))]));
}