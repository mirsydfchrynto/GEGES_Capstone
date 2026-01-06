import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class ManualBookingForm extends StatefulWidget {
  final Barbershop barbershop; final QueueService queueService;
  const ManualBookingForm({super.key, required this.barbershop, required this.queueService});
  @override State<ManualBookingForm> createState() => ManualBookingFormState();
}

class ManualBookingFormState extends State<ManualBookingForm> {
  final BarbershopService _bs = BarbershopService();
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kCardBg = Color(0xFF1A1A1A);

  int _currentStep = 0; 
  List<Service> _availableServices = [];
  final List<Service> _selectedServices = [];
  bool _isPremiumChoice = false; 
  Barberman? _selectedBarberman; 
  late DateTime _selectedDate; TimeOfDay? _selectedTime;
  bool _submitting = false;

  final TextEditingController _custNameCtrl = TextEditingController();
  final TextEditingController _custPhoneCtrl = TextEditingController();
  String _paymentMethod = 'cash'; 

  int get _totalPrice => _selectedServices.fold(0, (p, s) => p + s.price.toInt()) + (_isPremiumChoice ? widget.barbershop.barberSelectionFee : 0);

  @override void initState() { super.initState(); _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day); _initData(); }

  Future<void> _initData() async {
    try { final all = await _bs.getAllServices(); final shopSet = widget.barbershop.services.toSet(); setState(() => _availableServices = all.where((s) => shopSet.contains(s.id)).toList()); } catch (_) {}
  }

  void _nextStep() {
    if (_currentStep == 0 && _selectedServices.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih layanan"))); return; }
    if (_currentStep == 1 && _isPremiumChoice && _selectedBarberman == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pilih barber"))); return; }
    setState(() => _currentStep++);
  }

  @override Widget build(BuildContext context) {
    return Container(color: Colors.black, child: Column(children: [_buildStepIndicator(), Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: _buildCurrentStep())), _buildBottomSummary()]));
  }

  Widget _buildStepIndicator() {
    return Container(padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 30), child: Row(children: [_circle(0, "Layanan"), _line(0), _circle(1, "Barber"), _line(1), _circle(2, "Jadwal")]));
  }
  Widget _circle(int i, String l) { bool a = _currentStep >= i; return Column(children: [CircleAvatar(radius: 12, backgroundColor: a ? kBrownAccent : Colors.white10, child: Text("${i + 1}", style: TextStyle(color: a ? Colors.black : Colors.white38, fontSize: 12, fontWeight: FontWeight.bold))), const SizedBox(height: 4), Text(l, style: TextStyle(color: a ? kBrownAccent : Colors.white24, fontSize: 10))]); }
  Widget _line(int i) => Expanded(child: Divider(color: _currentStep > i ? kBrownAccent : Colors.white10, thickness: 2, indent: 10, endIndent: 10));

  Widget _buildCurrentStep() {
    if (_currentStep == 0) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Pilih Layanan Offline", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), ..._availableServices.map((s) { bool sel = _selectedServices.any((item) => item.id == s.id); return Padding(padding: const EdgeInsets.only(bottom: 12), child: InkWell(onTap: () => setState(() => sel ? _selectedServices.removeWhere((i) => i.id == s.id) : _selectedServices.add(s)), child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sel ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? kBrownAccent : Colors.transparent)), child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), Text("Rp ${s.price.toInt()}", style: const TextStyle(color: Colors.white54, fontSize: 12))])), Icon(sel ? Icons.check_circle : Icons.circle_outlined, color: sel ? kBrownAccent : Colors.white10)])))); })]);
    if (_currentStep == 1) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Pilihan Hairstylist", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 20), _choice(Icons.shuffle, "Acak / Otomatis", "System pilih barber tersedia", !_isPremiumChoice, () => setState(() => _isPremiumChoice = false)), const SizedBox(height: 12), _choice(Icons.person_search, "Request Barber Spesifik", "Customer request barber tertentu", _isPremiumChoice, () => setState(() => _isPremiumChoice = true)), if (_isPremiumChoice) ...[const SizedBox(height: 30), _buildBarberList()]]);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text("Data Pelanggan", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      TextField(controller: _custNameCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Nama Pelanggan (Opsional)', filled: true, fillColor: kCardBg)), const SizedBox(height: 12),
      TextField(controller: _custPhoneCtrl, style: const TextStyle(color: Colors.white), keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'No. HP (Opsional)', filled: true, fillColor: kCardBg)), const SizedBox(height: 24),
      const Text("Metode Pembayaran", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
      Row(children: [Expanded(child: _payOpt("Tunai", "cash", Icons.money)), const SizedBox(width: 12), Expanded(child: _payOpt("Transfer", "transfer", Icons.account_balance))]), const SizedBox(height: 24),
      _buildDateGrid(), const SizedBox(height: 24), _buildTimeGrid()
    ]);
  }

  Widget _choice(IconData i, String t, String s, bool sel, VoidCallback o) => InkWell(onTap: o, child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: sel ? kBrownAccent.withValues(alpha: 0.1) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: sel ? kBrownAccent : Colors.transparent)), child: Row(children: [Icon(i, color: sel ? kBrownAccent : Colors.white24, size: 28), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(color: sel ? kBrownAccent : Colors.white, fontWeight: FontWeight.bold)), Text(s, style: const TextStyle(color: Colors.white54, fontSize: 11))])), if (sel) const Icon(Icons.check_circle, color: kBrownAccent, size: 20)])));
  Widget _payOpt(String l, String v, IconData i) { bool s = _paymentMethod == v; return InkWell(onTap: () => setState(() => _paymentMethod = v), child: Container(padding: const EdgeInsets.symmetric(vertical: 16), decoration: BoxDecoration(color: s ? kBrownAccent.withValues(alpha: 0.2) : kCardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: s ? kBrownAccent : Colors.transparent)), child: Column(children: [Icon(i, color: s ? kBrownAccent : Colors.white54), const SizedBox(height: 8), Text(l, style: TextStyle(color: s ? kBrownAccent : Colors.white54, fontWeight: FontWeight.bold))]))); }

  Widget _buildBarberList() {
    return FutureBuilder<List<Barberman>>(future: _bs.getBarbermenByShop(widget.barbershop.id), builder: (context, snap) {
      if (!snap.hasData) return const LinearProgressIndicator(color: kBrownAccent);
      final list = snap.data!.where((b) => b.isActive).toList();
      return Wrap(spacing: 12, runSpacing: 12, children: list.map((b) { bool s = _selectedBarberman?.id == b.id; return InkWell(onTap: () => setState(() => _selectedBarberman = b), child: Column(children: [CircleAvatar(radius: 30, backgroundColor: s ? kBrownAccent : kCardBg, child: const Icon(Icons.person, color: Colors.white24)), const SizedBox(height: 4), Text(b.name, style: TextStyle(color: s ? kBrownAccent : Colors.white70, fontSize: 11))])); }).toList());
    });
  }

  Widget _buildDateGrid() {
    return SizedBox(height: 80, child: ListView.builder(scrollDirection: Axis.horizontal, itemCount: 7, itemBuilder: (context, i) {
      final d = DateTime.now().add(Duration(days: i)); bool sel = _selectedDate.day == d.day;
      return Padding(padding: const EdgeInsets.only(right: 10), child: InkWell(onTap: () => setState(() { _selectedDate = d; _selectedTime = null; }), child: Container(width: 60, decoration: BoxDecoration(color: sel ? kBrownAccent : kCardBg, borderRadius: BorderRadius.circular(12)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text(DateFormat('EEE').format(d), style: TextStyle(color: sel ? Colors.black : Colors.white38, fontSize: 10)), Text("${d.day}", style: TextStyle(color: sel ? Colors.black : Colors.white, fontSize: 16, fontWeight: FontWeight.bold))]))));
    }));
  }

  Widget _buildTimeGrid() {
    final List<TimeOfDay> times = [];
    for (int h = widget.barbershop.openHour; h < widget.barbershop.closeHour; h++) { times.add(TimeOfDay(hour: h, minute: 0)); times.add(TimeOfDay(hour: h, minute: 30)); }
    return GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2), itemCount: times.length, itemBuilder: (context, i) {
      final t = times[i]; bool s = _selectedTime == t; bool p = (_selectedDate.day == DateTime.now().day && (t.hour < DateTime.now().hour || (t.hour == DateTime.now().hour && t.minute < DateTime.now().minute)));
      return InkWell(onTap: () => setState(() { _selectedTime = t; }), child: Container(decoration: BoxDecoration(color: s ? kBrownAccent : (p ? Colors.white.withValues(alpha: 0.05) : kCardBg), borderRadius: BorderRadius.circular(8), border: Border.all(color: s ? kBrownAccent : Colors.white10)), alignment: Alignment.center, child: Text("${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}", style: TextStyle(color: s ? Colors.black : (p ? Colors.white24 : Colors.white), fontWeight: FontWeight.bold, fontSize: 13))));
    });
  }

  Widget _buildBottomSummary() {
    bool can = (_currentStep == 0 && _selectedServices.isNotEmpty) || (_currentStep == 1 && (!_isPremiumChoice || _selectedBarberman != null)) || (_currentStep == 2 && _selectedTime != null);
    return Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: kCardBg, border: Border(top: BorderSide(color: Colors.white10))), child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [const Text("Total (Tunai)", style: TextStyle(color: Colors.white54, fontSize: 12)), Text("Rp ${NumberFormat('#,###', 'id_ID').format(_totalPrice)}", style: const TextStyle(color: kBrownAccent, fontSize: 18, fontWeight: FontWeight.bold))])),
      ElevatedButton(onPressed: (can && !_submitting) ? (_currentStep == 2 ? _submit : _nextStep) : null, style: ElevatedButton.styleFrom(backgroundColor: kBrownAccent, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15)), child: _submitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)) : Text(_currentStep == 2 ? "BOOKING" : "LANJUT")),
    ]));
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final bdt = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _selectedTime!.hour, _selectedTime!.minute);
      final barberId = _isPremiumChoice ? _selectedBarberman!.id : (await widget.queueService.getFairAvailableBarberman(barbershopId: widget.barbershop.id, bookingTime: bdt, serviceIds: _selectedServices.map((s) => s.id).toList())) ?? '';
      
      // Auto-generate name if empty
      String name = _custNameCtrl.text.trim();
      if (name.isEmpty) {
        final rand = Random().nextInt(9999).toString().padLeft(4, '0');
        name = "Walk-in #$rand";
      }
      
      // Use '-' for phone if empty
      String phone = _custPhoneCtrl.text.trim();
      if (phone.isEmpty) phone = "-";

      await widget.queueService.createQueue({
        'barbershop_id': widget.barbershop.id, 
        'barberman_id': barberId, 
        'customer_id': 'MANUAL_${DateTime.now().millisecondsSinceEpoch}', 
        'customer_name': name, 
        'customer_phone': phone, 
        'customer_is_manual': true, 
        'service_ids': _selectedServices.map((s) => s.id).toList(), 
        'total_price': _totalPrice, 
        'booking_time': Timestamp.fromDate(bdt), 
        'status': 'booked', 
        'payment_method': _paymentMethod,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) { 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"))); 
    } finally { 
      if (mounted) setState(() => _submitting = false); 
    }
  }
}