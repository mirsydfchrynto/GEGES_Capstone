import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barbershop.dart';
import 'package:geges_smartbarber/models/service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';
import 'package:intl/intl.dart';

class ServicesTab extends StatefulWidget {
  final Barbershop shop;
  const ServicesTab({super.key, required this.shop});
  @override State<ServicesTab> createState() => _ServicesTabState();
}

class _ServicesTabState extends State<ServicesTab> {
  final BarbershopService _service = BarbershopService();
  final NumberFormat _currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  @override Widget build(BuildContext context) {
    return FutureBuilder<List<Service>>(
      future: _service.getAllServices(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: Color(0xFFC3A47B)));
        final all = snap.data ?? [];
        final shopIds = Set.from(widget.shop.services);
        final list = all.where((s) => shopIds.contains(s.id) && s.isActive).toList();
        if (list.isEmpty) return const Center(child: Text("Belum ada layanan tersedia.", style: TextStyle(color: Colors.white54)));
        return ListView.separated(padding: const EdgeInsets.all(24), itemCount: list.length, separatorBuilder: (c, i) => const SizedBox(height: 16), itemBuilder: (c, i) {
          final s = list[i]; return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)), if (s.description.isNotEmpty) Text(s.description, style: const TextStyle(color: Colors.white54, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis), Text('${s.defaultDuration} Min', style: const TextStyle(color: Colors.white70, fontSize: 14))])), const SizedBox(width: 16), Text(_currency.format(s.price), style: const TextStyle(color: Color(0xFFC3A47B), fontSize: 16, fontWeight: FontWeight.bold))]));
        });
      },
    );
  }
}