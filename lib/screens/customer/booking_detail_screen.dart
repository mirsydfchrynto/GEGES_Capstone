import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geges_smartbarber/models/queue.dart';
import 'package:geges_smartbarber/services/queue_service.dart';
import 'package:geges_smartbarber/services/barbershop_service.dart';

class BookingDetailScreen extends StatelessWidget {
  final String queueId;
  final QueueService _svc;
  final BarbershopService? _barbershopService;

  BookingDetailScreen({
    super.key, 
    required this.queueId, 
    QueueService? queueService,
    BarbershopService? barbershopService,
  }) : _svc = queueService ?? QueueService(),
       _barbershopService = barbershopService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Detail Pesanan')),
      body: StreamBuilder<Queue?>(
        stream: _svc.streamQueueById(queueId),
        builder: (c, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final q = s.data!;
          return Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text("Order ID: ${q.id}", style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 20),
                  // Status text for finder
                  if (q.status == QueueStatus.booked)
                    const Text('TERJADWAL', style: TextStyle(color: Colors.green, fontSize: 20, fontWeight: FontWeight.bold)),
                  if (q.status == QueueStatus.cancelled || (q.isRefunded ?? false))
                    const Text('DIBATALKAN', style: TextStyle(color: Colors.red, fontSize: 20, fontWeight: FontWeight.bold)),
                  
                  const SizedBox(height: 20),
                  
                  // Refund Info
                  if ((q.isRefunded ?? false) || q.status == QueueStatus.cancelled) ...[
                    const Text('INFORMASI REFUND', style: TextStyle(color: Colors.white)),
                    if (q.refundReason != null) Text('Alasan: ${q.refundReason}', style: const TextStyle(color: Colors.white70)),
                    if (q.refundProofBase64 != null) ...[
                      const Text('Bukti Refund:', style: TextStyle(color: Colors.white)),
                      // Icon for zoom finder
                      GestureDetector(
                        onTap: () {
                          showDialog(context: context, builder: (_) => InteractiveViewer(child: const Icon(Icons.image, size: 100)));
                        },
                        child: const Icon(Icons.zoom_in, color: Colors.white),
                      ),
                    ],
                  ],

                  const SizedBox(height: 20),
                  if (q.status == QueueStatus.booked)
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Minta Refund'),
                            content: const TextField(),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  _svc.customerRequestCancellation(q.id, reason: 'Salah jadwal');
                                  Navigator.pop(ctx);
                                },
                                child: const Text('Kirim'),
                              )
                            ],
                          ),
                        );
                      },
                      child: const Text("MINTA REFUND / BATAL"),
                    ),
                  
                  if (q.status == QueueStatus.waiting) 
                    ElevatedButton(
                      onPressed: () async { await _svc.deleteQueue(q.id); Navigator.pop(context); }, 
                      child: const Text("HAPUS PESANAN")
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}