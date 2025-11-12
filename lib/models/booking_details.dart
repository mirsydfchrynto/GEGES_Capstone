// lib/models/booking_details.dart (Simulasi data gabungan)
import 'package:geges_smartbarber/models/queue.dart'; 
// Import model lain yang diperlukan (Barbershop, Barberman)

class BookingDetails {
  final Queue queue;
  final String barbershopName;
  final String barbermanName;
  final String serviceName; // Asumsi service name juga berhasil di-fetch
  final String barbershopImage;
  
  // Konstruktor sederhana
  BookingDetails({
    required this.queue,
    required this.barbershopName,
    required this.barbermanName,
    required this.serviceName,
    required this.barbershopImage,
  });
}
