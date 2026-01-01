import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BarbermanManagementScreen extends StatefulWidget {
  final String barbershopId;
  const BarbermanManagementScreen({super.key, required this.barbershopId});

  @override
  State<BarbermanManagementScreen> createState() => _BarbermanManagementScreenState();
}

class _BarbermanManagementScreenState extends State<BarbermanManagementScreen> {
  final BarbershopService _service = BarbershopService();
  
  @override
  Widget build(BuildContext context) {
    const Color kBrownAccent = Color(0xFFC3A47B);
    const Color kSurface = Color(0xFF0F0F0F);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        title: const Text('Manajemen Karyawan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: kSurface,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1, color: kBrownAccent),
            onPressed: () => _showEditDialog(null),
          ),
        ],
      ),
      body: FutureBuilder<List<Barberman>>(
        future: _service.getBarbermenByShop(widget.barbershopId),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator(color: kBrownAccent));
          final list = snap.data!;
          if (list.isEmpty) return const Center(child: Text('Belum ada karyawan', style: TextStyle(color: Colors.white54)));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final b = list[i];
              return _barberTile(b);
            },
          );
        },
      ),
    );
  }

  Widget _barberTile(Barberman b) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 25,
          backgroundColor: Colors.grey[900],
          backgroundImage: b.imageUrl != null ? NetworkImage(b.imageUrl!) : null,
          child: b.imageUrl == null ? const Icon(Icons.person, color: Colors.white24) : null,
        ),
        title: Text(b.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${b.avgDuration.toInt()} menit avg • ${b.monthlyHaircutCount} cukur bulan ini', style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 4),
            Row(
              children: [
                _statusBadge(b.isActive ? "AKTIF" : "NONAKTIF", b.isActive ? Colors.green : Colors.red),
                const SizedBox(width: 8),
                if (b.onLeave) _statusBadge("CUTI", Colors.orange),
              ],
            )
          ],
        ),
        trailing: IconButton(icon: const Icon(Icons.edit, color: Colors.white54), onPressed: () => _showEditDialog(b)),
      ),
    );
  }

  Widget _statusBadge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: c.withValues(alpha: 0.5))),
    child: Text(t, style: TextStyle(color: c, fontSize: 10, fontWeight: FontWeight.bold)),
  );

  void _showEditDialog(Barberman? b) {
    final nameCtrl = TextEditingController(text: b?.name);
    final durCtrl = TextEditingController(text: b?.avgDuration.toInt().toString() ?? "30");
    bool isActive = b?.isActive ?? true;
    bool onLeave = b?.onLeave ?? false;
    List<String> specificOff = List.from(b?.specificOffDays ?? []);
    List<DayOfWeek> weeklyOff = List.from(b?.offDays ?? []);

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
        builder: (ctx, scroll) => ListView(
          controller: scroll, padding: const EdgeInsets.all(24),
          children: [
            Text(b == null ? 'Tambah Karyawan' : 'Edit Karyawan', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            _input("Nama Lengkap", nameCtrl),
            const SizedBox(height: 16),
            _input("Rata-rata Durasi (menit)", durCtrl, isNum: true),
            const SizedBox(height: 24),
            
            SwitchListTile(title: const Text("Status Aktif", style: TextStyle(color: Colors.white)), value: isActive, onChanged: (v) => setS(() => isActive = v)),
            SwitchListTile(title: const Text("Sedang Cuti", style: TextStyle(color: Colors.white)), value: onLeave, onChanged: (v) => setS(() => onLeave = v)),
            
            const Divider(color: Colors.white10, height: 40),
            const Text("Libur Mingguan", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(spacing: 8, children: DayOfWeek.values.map((d) {
              bool sel = weeklyOff.contains(d);
              return FilterChip(
                label: Text(d.name.substring(0,3).toUpperCase()), selected: sel,
                onSelected: (v) => setS(() => v ? weeklyOff.add(d) : weeklyOff.remove(d)),
                selectedColor: const Color(0xFFC3A47B), labelStyle: TextStyle(color: sel ? Colors.black : Colors.white),
              );
            }).toList()),

            const SizedBox(height: 24),
            const Text("Jadwal Cuti Khusus", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18), label: const Text("Tambah Tanggal Cuti"),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) {
                  final s = DateFormat('yyyy-MM-dd').format(d);
                  if (!specificOff.contains(s)) setS(() => specificOff.add(s));
                }
              },
            ),
            Wrap(spacing: 8, children: specificOff.map((d) => Chip(label: Text(d), onDeleted: () => setS(() => specificOff.remove(d)))).toList()),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: () async {
                final barber = Barberman(
                  id: b?.id ?? '', name: nameCtrl.text, barbershopId: widget.barbershopId,
                  avgDuration: double.tryParse(durCtrl.text) ?? 30, rating: b?.rating ?? 5.0,
                  isActive: isActive, onLeave: onLeave, offDays: weeklyOff, specificOffDays: specificOff,
                  monthlyHaircutCount: b?.monthlyHaircutCount ?? 0,
                );
                await _service.saveBarberman(barber);
                if (!mounted) return;
                Navigator.of(context).pop();
                setState(() {});
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFC3A47B), minimumSize: const Size.fromHeight(50)),
              child: const Text("SIMPAN KARYAWAN", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 50),
          ],
        ),
      )),
    );
  }

  Widget _input(String l, TextEditingController c, {bool isNum = false}) => TextField(
    controller: c, keyboardType: isNum ? TextInputType.number : TextInputType.text,
    style: const TextStyle(color: Colors.white),
    decoration: InputDecoration(labelText: l, labelStyle: const TextStyle(color: Colors.white54), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
  );
}