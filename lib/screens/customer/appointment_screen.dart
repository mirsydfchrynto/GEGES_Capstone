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

  const AppointmentScreen({
    super.key,
    required this.barbershop,
    this.barbershopService,
    this.queueService,
    this.testUserId,
  });

  @override
  State<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends State<AppointmentScreen> {
  // Services
  late BarbershopService _barbershopService;
  late final QueueService _queueService;

  // Theme
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kSurface = Color(0xFF0F0F0F);
  static const Color kCardBg = Color(0xFF1A1A1A);

  // State: Wizard Steps
  int _currentStep = 0; // 0: Services, 1: Specialist, 2: Schedule

  // State: Data
  final List<Service> _selectedServices = [];
  bool _isPremiumChoice = false; // User wants specific barber
  Barberman? _selectedBarberman; // The one they picked (if premium)
  Barberman? _autoBarberman; // The one system picks (if fair)
  
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  
  bool _isLoading = false;
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
    _barbershopService = widget.barbershopService ?? BarbershopService();
    _queueService = widget.queueService ?? QueueService();
    
    // Initial date: today or tomorrow if closed
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    
    // Auto-advance if store is closed today? (Optional)
  }

  // ---------- LOGIC ----------

  bool _isShopOpenOn(DateTime date) {
    // 1. Check Weekly Holiday
    if (widget.barbershop.weeklyHolidays.contains(date.weekday % 7)) return false;
    // 2. Check Specific Holiday
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
        // User picked a specific one, just check if HE is available
        if (_selectedBarberman == null) throw "Pilih barber terlebih dahulu";
        
        final isAvailable = await _queueService.isSlotAvailable(
          barbershopId: widget.barbershop.id,
          barbermanId: _selectedBarberman!.id,
          bookingTime: bookingDateTime,
          serviceIds: _selectedServices.map((s) => s.id).toList(),
        );
        
        if (!isAvailable) throw "Barber tersebut sudah ada jadwal di jam ini";
      } else {
        // Fairness Algorithm: System picks
        final fairId = await _queueService.getFairAvailableBarberman(
          barbershopId: widget.barbershop.id,
          bookingTime: bookingDateTime,
          serviceIds: _selectedServices.map((s) => s.id).toList(),
        );
        
        if (fairId == null) {
          debugPrint("AppointmentScreen: No fair available barber found for $bookingDateTime");
          throw "Tidak ada hairstylist tersedia jam ini. Coba jam lain.";
        }
        
        final b = await _barbershopService.getBarbermanById(fairId);
        setState(() => _autoBarberman = b);
      }
    } catch (e) {
      setState(() => _availabilityError = e.toString());
    } finally {
      setState(() => _isCheckingAvailability = false);
    }
  }

  void _nextStep() {
    if (_currentStep < 2) {
      // Validation before moving
      if (_currentStep == 0 && _selectedServices.isEmpty) {
        _showSnack("Pilih minimal satu layanan");
        return;
      }
      if (_currentStep == 1 && _isPremiumChoice && _selectedBarberman == null) {
        _showSnack("Silakan pilih barber favorit Anda");
        return;
      }
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ---------- UI BUILDERS ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text(widget.barbershop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => _currentStep > 0 ? _prevStep() : Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildProgressHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: _buildCurrentStepView(),
            ),
          ),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
      child: Row(
        children: [
          _stepDot(0, "Layanan"),
          _stepLine(0),
          _stepDot(1, "Barber"),
          _stepLine(1),
          _stepDot(2, "Jadwal"),
        ],
      ),
    );
  }

  Widget _stepDot(int index, String label) {
    bool active = _currentStep >= index;
    return Column(
      children: [
        CircleAvatar(
          radius: 12,
          backgroundColor: active ? kBrownAccent : Colors.grey[800],
          child: Text("${index + 1}", style: TextStyle(color: active ? Colors.black : Colors.white54, fontSize: 12, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: active ? kBrownAccent : Colors.white24, fontSize: 10)),
      ],
    );
  }

  Widget _stepLine(int index) {
    bool active = _currentStep > index;
    return Expanded(child: Divider(color: active ? kBrownAccent : Colors.grey[800], thickness: 2, indent: 8, endIndent: 8));
  }

  Widget _buildCurrentStepView() {
    switch (_currentStep) {
      case 0: return _buildServiceStep();
      case 1: return _buildBarberStep();
      case 2: return _buildScheduleStep();
      default: return const SizedBox();
    }
  }

  // --- STEP 1: SERVICES ---
  Widget _buildServiceStep() {
    return FutureBuilder<List<Service>>(
      future: _barbershopService.getAllServices(),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
        final shopServices = snap.data!.where((s) => widget.barbershop.services.contains(s.id)).toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Pilih Layanan", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Anda bisa memilih lebih dari satu layanan", style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 24),
            ...shopServices.map((s) => _serviceCard(s)),
          ],
        );
      },
    );
  }

  Widget _serviceCard(Service s) {
    bool isSelected = _selectedServices.any((item) => item.id == s.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          setState(() {
            isSelected ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("${s.defaultDuration} mnt • Rp ${s.price.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 13)),
                  ],
                ),
              ),
              Checkbox(
                value: isSelected,
                onChanged: (_) {
                  setState(() {
                    isSelected ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s);
                  });
                },
                activeColor: kBrownAccent,
                checkColor: Colors.black,
              )
            ],
          ),
        ),
      ),
    );
  }

  // --- STEP 2: BARBER ---
  Widget _buildBarberStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Siapa yang mencukur?", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Option 1: System Picks (Auto)
        _choiceCard(
          icon: Icons.auto_awesome,
          title: "Dipilihkan Sistem (Adil & Cepat)",
          subtitle: "Sistem akan mencarikan barber terbaik yang tersedia untuk Anda.",
          isSelected: !_isPremiumChoice,
          onTap: () => setState(() { _isPremiumChoice = false; _selectedBarberman = null; }),
        ),
        const SizedBox(height: 16),
        
        // Option 2: User Picks (Premium)
        _choiceCard(
          icon: Icons.stars,
          title: "Pilih Barber Favorit",
          subtitle: "Pilih barber tertentu yang sudah Anda kenal (+ Rp ${widget.barbershop.barberSelectionFee})",
          isSelected: _isPremiumChoice,
          onTap: () => setState(() => _isPremiumChoice = true),
        ),
        
        if (_isPremiumChoice) ...[
          const SizedBox(height: 32),
          const Text("Daftar Specialist", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildBarberList(),
        ]
      ],
    );
  }

  Widget _choiceCard({required IconData icon, required String title, required String subtitle, required bool isSelected, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected ? kBrownAccent.withValues(alpha: 0.1) : kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? kBrownAccent : Colors.white24, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: isSelected ? kBrownAccent : Colors.white, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                ],
              ),
            ),
            if (isSelected) const Icon(Icons.check_circle, color: kBrownAccent, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildBarberList() {
    return FutureBuilder<List<Barberman>>(
      future: _barbershopService.getBarbermenByShop(widget.barbershop.id),
      builder: (context, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
        final activeBarbers = snap.data!.where((b) => b.isActive).toList();
        
        return SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: activeBarbers.length,
            itemBuilder: (context, i) {
              final b = activeBarbers[i];
              bool isSelected = _selectedBarberman?.id == b.id;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedBarberman = b),
                  child: Column(
                    children: [
                      Container(
                        width: 70, height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? kBrownAccent : Colors.transparent, width: 2),
                          image: b.imageUrl != null 
                            ? DecorationImage(image: CachedNetworkImageProvider(b.imageUrl!), fit: BoxFit.cover)
                            : null,
                          color: Colors.grey[900],
                        ),
                        child: b.imageUrl == null ? const Icon(Icons.person, color: Colors.white24) : null,
                      ),
                      const SizedBox(height: 8),
                      Text(b.name, style: TextStyle(color: isSelected ? kBrownAccent : Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- STEP 3: SCHEDULE ---
  Widget _buildScheduleStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Tentukan Jadwal", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        
        // Date Selector
        const Text("Pilih Hari", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 12),
        _buildDateRow(),
        
        const SizedBox(height: 32),
        
        // Time Selector
        const Text("Pilih Jam", style: TextStyle(color: Colors.white70, fontSize: 14)),
        const SizedBox(height: 12),
        _buildTimeGrid(),
        
        if (_availabilityError != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.redAccent),
                const SizedBox(width: 12),
                Expanded(child: Text(_availabilityError!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
              ],
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildDateRow() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 14, // 2 weeks
        itemBuilder: (context, i) {
          final date = DateTime.now().add(Duration(days: i));
          bool isOpen = _isShopOpenOn(date);
          bool isSelected = _selectedDate.day == date.day && _selectedDate.month == date.month;
          
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: InkWell(
              onTap: isOpen ? () => setState(() { _selectedDate = date; _selectedTime = null; _availabilityError = null; }) : null,
              child: Container(
                width: 65,
                decoration: BoxDecoration(
                  color: isSelected ? kBrownAccent : (isOpen ? kCardBg : Colors.black26),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(DateFormat('EEE').format(date), style: TextStyle(color: isSelected ? Colors.black : Colors.white54, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text("${date.day}", style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    if (!isOpen) const Text("LIBUR", style: TextStyle(color: Colors.redAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                  ],
                ),
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
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2),
      itemCount: times.length,
      itemBuilder: (context, i) {
        final t = times[i];
        bool isSelected = _selectedTime == t;
        
        // Disable past time for today
        bool isPast = false;
        if (_selectedDate.day == DateTime.now().day) {
          if (t.hour < DateTime.now().hour || (t.hour == DateTime.now().hour && t.minute < DateTime.now().minute)) {
            isPast = true;
          }
        }

        return InkWell(
          onTap: isPast ? null : () {
            setState(() { _selectedTime = t; _availabilityError = null; });
            _checkBarberAvailability();
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? kBrownAccent : (isPast ? Colors.transparent : kCardBg),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isSelected ? kBrownAccent : (isPast ? Colors.white10 : Colors.transparent)),
            ),
            alignment: Alignment.center,
            child: Text(
              "${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}",
              style: TextStyle(color: isSelected ? Colors.black : (isPast ? Colors.white10 : Colors.white), fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  // --- BOTTOM BAR ---
  Widget _buildBottomSummary() {
    bool canProceed = false;
    String btnText = "LANJUT";
    
    if (_currentStep == 0 && _selectedServices.isNotEmpty) canProceed = true;
    if (_currentStep == 1) {
      if (!_isPremiumChoice) canProceed = true;
      if (_isPremiumChoice && _selectedBarberman != null) canProceed = true;
    }
    if (_currentStep == 2) {
      if (_selectedTime != null && _availabilityError == null && !_isCheckingAvailability) {
        canProceed = true;
        btnText = "BOOK NOW";
      }
    }

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(color: kCardBg, border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05)))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Total Estimasi", style: TextStyle(color: Colors.white54, fontSize: 12)),
                Text(NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(_totalPrice), style: const TextStyle(color: kBrownAccent, fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(
            width: 140, height: 50,
            child: ElevatedButton(
              onPressed: (canProceed && !_isLoading) ? (_currentStep == 2 ? _processBooking : _nextStep) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent, disabledBackgroundColor: Colors.white10,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.black) : Text(btnText, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processBooking() async {
    setState(() => _isLoading = true);
    
    final bookingDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime!.hour, _selectedTime!.minute,
    );
    
    final customerId = widget.testUserId ?? FirebaseAuth.instance.currentUser?.uid;
    final barberId = _isPremiumChoice ? _selectedBarberman!.id : _autoBarberman!.id;
    final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

    final payload = {
      'barbershop_id': widget.barbershop.id,
      'customer_id': customerId,
      'barberman_id': barberId,
      'service_ids': _selectedServices.map((s) => s.id).toList(),
      'total_price': _totalPrice,
      'barber_selection_fee': _selectionFee,
      'paid_barber_selection': _isPremiumChoice,
      'is_auto_assigned': !_isPremiumChoice,
      'estimated_duration': _totalDuration,
      'booking_time': Timestamp.fromDate(bookingDateTime),
      'status': 'awaiting_payment',
      'request_status': 'approved',
      'payment_deadline': Timestamp.fromDate(DateTime.now().add(const Duration(minutes: 15))),
      'order_id': orderId,
    };

    try {
      await _queueService.createQueue(payload);
      if (!mounted) return;
      
      Navigator.of(context).push(MaterialPageRoute(builder: (c) => PaymentScreen(
        orderId: orderId,
        totalPrice: _totalPrice,
        barbershopId: widget.barbershop.id,
        barbermanId: barberId,
        bookingTime: bookingDateTime,
        paymentDeadline: DateTime.now().add(const Duration(minutes: 15)),
      )));
    } catch (e) {
      _showSnack("Gagal: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
}