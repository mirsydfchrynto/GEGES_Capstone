import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/barberman.dart';
import 'package:geges_smartbarber/services/barberman_service.dart';

class BarberManagementScreen extends StatefulWidget {
  final String barbershopId;

  /// Optional: inject a BarbermanService for tests
  final BarbermanService? barbermanService;
  const BarberManagementScreen({
    super.key,
    required this.barbershopId,
    this.barbermanService,
  });

  @override
  State<BarberManagementScreen> createState() => _BarberManagementScreenState();
}

class _BarberManagementScreenState extends State<BarberManagementScreen> {
  late final BarbermanService _svc;

  @override
  void initState() {
    super.initState();
    _svc = widget.barbermanService ?? BarbermanService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kelola Barber'),
        actions: [
          IconButton(
            tooltip: 'Set Off Day For All',
            icon: const Icon(Icons.event_busy_outlined),
            onPressed: () async {
              final day = await showDialog<DayOfWeek?>(
                context: context,
                builder: (c) {
                  DayOfWeek? sel;
                  return StatefulBuilder(
                    builder: (ctx, setS) => AlertDialog(
                      title: const Text('Pilih hari libur untuk semua barber'),
                      content: DropdownButton<DayOfWeek>(
                        value: sel,
                        hint: const Text('Pilih hari'),
                        items: DayOfWeek.values
                            .map(
                              (d) => DropdownMenuItem(
                                value: d,
                                child: Text(d.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setS(() => sel = v),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(c).pop(null),
                          child: const Text('Batal'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(c).pop(sel),
                          child: const Text('Terapkan'),
                        ),
                      ],
                    ),
                  );
                },
              );
              if (day == null) return;

              final String dayName = day.name;
              // Use the injected service to apply the change so tests can inject a FakeFirestore
              try {
                final previous = await _svc.applyOffDayToAll(
                  widget.barbershopId,
                  dayName,
                );
                if (previous.isEmpty) {
                  if (!mounted) return;
                  // ignore: use_build_context_synchronously
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Semua barber sudah memiliki hari libur tersebut',
                      ),
                      backgroundColor: Colors.blue,
                    ),
                  );
                  return;
                }

                if (!mounted) return;
                // ignore: use_build_context_synchronously
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Hari libur diterapkan ke semua barber',
                    ),
                    backgroundColor: Colors.green,
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () async {
                        try {
                          await _svc.revertOffDayByPrevious(previous);
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Perubahan dibatalkan'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        } catch (e) {
                          if (!mounted) return;
                          // ignore: use_build_context_synchronously
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Gagal membatalkan perubahan'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                // ignore: use_build_context_synchronously
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Gagal menerapkan hari libur'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Barberman>>(
        stream: _svc.streamBarbermenByBarbershop(widget.barbershopId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const Center(child: Text('Belum ada barber'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (c, i) => _barberCard(list[i]),
          );
        },
      ),
    );
  }

  Widget _barberCard(Barberman b) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  b.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Switch(
                  value: b.onLeave,
                  onChanged: (val) async {
                    final updated = Barberman(
                      id: b.id,
                      name: b.name,
                      barbershopId: b.barbershopId,
                      imageUrl: b.imageUrl,
                      avgDuration: b.avgDuration,
                      rating: b.rating,
                      isActive: b.isActive,
                      offDays: b.offDays,
                      annualLeaveDays: b.annualLeaveDays,
                      onLeave: val,
                    );
                    await _svc.saveBarberman(updated);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('Hari libur mingguan:'),
            Wrap(
              spacing: 6,
              children: DayOfWeek.values.map((d) {
                final isSel = b.offDays?.contains(d) ?? false;
                return FilterChip(
                  label: Text(d.name.substring(0, 3).toUpperCase()),
                  selected: isSel,
                  onSelected: (sel) async {
                    // create a mutable copy of existing offDays (or empty list)
                    final newOff = List<DayOfWeek>.from(b.offDays ?? []);
                    if (sel) {
                      newOff.add(d);
                    } else {
                      newOff.removeWhere((e) => e == d);
                    }
                    final updated = Barberman(
                      id: b.id,
                      name: b.name,
                      barbershopId: b.barbershopId,
                      imageUrl: b.imageUrl,
                      avgDuration: b.avgDuration,
                      rating: b.rating,
                      isActive: b.isActive,
                      offDays: newOff,
                      annualLeaveDays: b.annualLeaveDays,
                      onLeave: b.onLeave,
                    );
                    await _svc.saveBarberman(updated);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Text('Sisa cuti tahunan: ${b.annualLeaveDays}'),
          ],
        ),
      ),
    );
  }
}
