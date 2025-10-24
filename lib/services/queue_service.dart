import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
// Pastikan path ke model queue.dart Anda benar
import 'package:geges_smartbarber/models/queue.dart'; 

class QueueService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Mendapatkan stream/listener antrean yang masih 'pending' atau 'ongoing'
  // Admin akan melihat antrean ini secara real-time
  Stream<List<Queue>> getActiveQueueStream(String barbershopId) {
    return _firestore
        .collection('queues')
        .where('barbershop_id', isEqualTo: barbershopId)
        // Ambil antrean yang belum selesai (pending ATAU ongoing)
        .where('status', whereIn: ['pending', 'ongoing']) 
        // TODO: Nanti tambahkan orderby 'booking_time'
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Queue.fromFirestore(doc)).toList();
    });
  }

  // Fungsi saat Admin/Kasir menekan "Mulai Potong"
  Future<void> startService(String queueId) async {
    try {
      await _firestore.collection('queues').doc(queueId).update({
        'start_time': FieldValue.serverTimestamp(),
        'status': 'ongoing',
      });
    } catch (e) {
      print("Error starting service: $e");
    }
  }

  // Fungsi saat Admin/Kasir menekan "Selesai Potong"
  // Ini adalah INPUT PENTING untuk AI
  Future<void> finishService(String queueId, Timestamp startTime) async {
    try {
      Timestamp finishTime = Timestamp.now();
      
      // Menghitung durasi aktual dalam menit
      // (finishTime.seconds - startTime.seconds) akan memberikan total detik
      // dibagi 60 untuk mendapatkan menit.
      int actualDurationInMinutes = (finishTime.seconds - startTime.seconds) ~/ 60;
      
      // Pastikan durasi minimal 1 menit jika < 60 detik
      if (actualDurationInMinutes == 0) {
        actualDurationInMinutes = 1;
      }

      await _firestore.collection('queues').doc(queueId).update({
        'finish_time': finishTime,
        'status': 'served',
        'actual_duration': actualDurationInMinutes, // Data ini akan melatih AI
      });
      
      // TODO (Fase 4 - AI): Panggil fungsi untuk meng-update avg_duration barberman
      // updateBarbermanAverage(barbermanId, actualDurationInMinutes);

    } catch (e) {
      print("Error finishing service: $e");
    }
  }
  
  // Fungsi untuk Customer membuat antrean (Akan digunakan Tim 3)
  Future<void> createQueue(Map<String, dynamic> queueData) async {
     try {
      await _firestore.collection('queues').add({
        ...queueData,
        'status': 'pending',
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error creating queue: $e");
    }
  }
}

