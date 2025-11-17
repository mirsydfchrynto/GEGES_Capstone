# 📋 Dokumentasi: Booking Flow Baru (Phase 3)

**Status:** Dokumentasi Fitur - Untuk Development Phase 3-4  
**Bahasa:** Bahasa Indonesia (Pemula-Friendly)  
**Author:** Copilot (Dibantu untuk Project GEGES SmartBarber)

---

## 1. Ringkasan Alur Booking Baru

Alur booking aplikasi diubah untuk **meningkatkan keamanan dan kepuasan customer** dengan menambahkan tahap **konfirmasi admin sebelum pembayaran**.

### Alur Lama (Tidak Dipakai Lagi):
```
Customer Booking → Upload Bukti Bayar → Admin Verifikasi Payment
```

### Alur Baru (Sekarang):
```
Customer Request Booking 
    ↓
Admin Approve/Reject Request
    ↓ (jika approve)
Customer Upload Bukti Bayar (dalam 1 jam)
    ↓
Admin Verifikasi Payment
    ↓ (jika approve)
Barber Melayani
```

---

## 2. Status & Status Transition

### Status Utama (QueueStatus Enum)

| Status | Arti | Siapa Set | Notes |
|--------|------|-----------|-------|
| `waiting` | Menunggu approval admin | System (saat customer request) | Request booking baru |
| `booked` | Admin approve, customer bisa bayar | Admin | Payment window buka (1 jam) |
| `ongoing` | Admin approve payment, barber siap melayani | Admin | Barber bisa mulai |
| `served` | Selesai dilayani | Barber | Workflow selesai |
| `cancelled` | Dibatalkan | Admin / System | Request reject / payment timeout / payment tolak |

### Sub-Status Approval (RequestStatus Enum)

Tracking approval dari admin untuk request booking:

| Status | Arti | Keputusan Admin | Notes |
|--------|------|-----------------|-------|
| `pending` | Menunggu admin lihat & keputusan | Belum diputuskan | Default saat customer request |
| `approved` | Admin approve request, customer bayar sekarang | Approve | Payment window: 1 jam |
| `rejected` | Admin reject request | Reject | Tidak ada pembayaran, request hangus |

---

## 3. Database Schema (Firestore Collection: `queues`)

### Field Baru Untuk Booking Flow

```dart
// lib/models/queue.dart
final RequestStatus requestStatus;    // pending / approved / rejected
final Timestamp? paymentDeadline;     // Kapan payment window tutup
final String? paymentMethod;          // 'manual' atau 'digital' (future)
final String? rejectionReason;        // Alasan reject admin (optional)
final String? verifiedBy;             // User ID admin yang verify payment
```

### Struktur Lengkap Di Firestore

```json
{
  // identitas
  "id": "doc-id-dari-firebase",
  "barbershop_id": "barbershop-123",
  "customer_id": "customer-456",
  "barberman_id": "barberman-789",
  
  // waktu
  "booking_time": Timestamp(created),
  "start_time": Timestamp(barber mulai) or null,
  "finish_time": Timestamp(selesai) or null,
  
  // durasi & harga
  "estimated_duration": 30,     // menit
  "actual_duration": 32,        // menit
  "service_ids": ["service-1", "service-2"],
  "total_price": 150000,
  
  // status utama
  "status": "booked",     // waiting, booked, ongoing, served, cancelled
  
  // NEW: sub-status approval
  "request_status": "approved",  // pending, approved, rejected
  
  // NEW: payment tracking
  "payment_method": "manual",
  "payment_deadline": Timestamp(2025-11-18 10:00:00),
  "payment_proof_base64": "iVBORw0KGgo...", // bukti pembayaran
  "verified_by": "admin-user-id",
  
  // NEW: rejection tracking
  "rejection_reason": "Slot tidak tersedia pada jam tersebut",
  
  // meta
  "created_at": Timestamp.serverTimestamp()
}
```

---

## 4. Timeline Booking

Berikut contoh timeline lengkap untuk satu booking:

### Skenario 1: Booking Sukses

```
[11:00] Customer request booking (Booking created)
        status: "waiting"
        request_status: "pending"
        
[11:02] Admin approve booking
        status: "waiting" (masih, belum payment)
        request_status: "approved"
        payment_deadline: 11:03 (1 jam dari approve)
        
[11:25] Customer upload bukti pembayaran
        payment_proof_base64: "iVBORw0KGgo..."
        
[11:27] Admin verifikasi payment
        status: "booked" → "ongoing"
        verified_by: "admin-123"
        
[11:30] Barber mulai melayani
        start_time: 11:30
        
[12:05] Barber selesai melayani
        status: "served"
        finish_time: 12:05
        actual_duration: 35 menit
```

### Skenario 2: Admin Reject Request

```
[11:00] Customer request booking
        status: "waiting"
        request_status: "pending"
        
[11:02] Admin reject booking
        status: "cancelled"
        request_status: "rejected"
        rejection_reason: "Barberman tidak tersedia"
        
[11:03] Customer dapat notifikasi reject
        (Tidak ada pembayaran)
```

### Skenario 3: Payment Timeout

```
[11:00] Customer request booking
[11:02] Admin approve
        payment_deadline: 12:02 (1 jam)
        
[12:03] (Otomatis via Cloud Function)
        Status expired karena customer tidak bayar dalam 1 jam
        status: "cancelled"
        rejection_reason: "Payment timeout (exceeded deadline)"
```

### Skenario 4: Admin Reject Payment

```
[11:00] Customer request booking
[11:02] Admin approve
[11:25] Customer upload bukti pembayaran
        
[11:27] Admin cek bukti, bukti tidak valid
        status: "cancelled"
        rejection_reason: "Bukti pembayaran tidak valid. Jumlah tidak sesuai."
        
[11:28] Customer dapat notif, bisa request ulang
```

---

## 5. Implementasi Di Screen

### Customer Side Flow

#### Screen: appointment_screen.dart
```dart
// OLD: Customer langsung upload payment
// NEW: Customer diminta untuk request booking dulu

// 1. Setelah customer pilih service & date/time:
void _submitRequest() {
  // Create queue dengan status: waiting
  Queue newRequest = Queue(
    id: FirebaseFirestore.instance.collection('queues').doc().id,
    barbershopId: _barbershop.id,
    customerId: _getCurrentUserId(),
    barbermanId: '', // belum ada, admin assign nanti
    bookingTime: Timestamp.now(),
    status: QueueStatus.waiting,
    requestStatus: RequestStatus.pending,  // NEW
    totalPrice: _selectedServices.fold<int>(0, (sum, s) => sum + s.price),
    serviceIds: _selectedServices.map((s) => s.id).toList(),
  );
  
  // Save ke Firestore
  await FirebaseFirestore.instance
      .collection('queues')
      .doc(newRequest.id)
      .set(newRequest.toJson());
  
  // Show dialog: "Request booking sudah dikirim, tunggu admin approve"
}
```

#### Screen: my_bookings_screen.dart
```dart
// NEW: Tampilkan request status
// Customer bisa lihat apakah request sudah approved atau belum

Widget _buildBookingCard(Queue queue) {
  // Cek request_status
  if (queue.requestStatus == RequestStatus.pending) {
    return Card(
      child: Column(
        children: [
          Text("Status: Menunggu Persetujuan Admin"),
          Text("Diajukan: ${queue.bookingTime.toDate()}"),
          // Customer tidak bisa apa-apa, hanya tunggu
        ],
      ),
    );
  }
  
  if (queue.requestStatus == RequestStatus.approved && 
      queue.status == QueueStatus.waiting) {
    // NEW: Waktu untuk bayar (payment window)
    Duration timeLeft = queue.paymentDeadline!.toDate().difference(
      DateTime.now(),
    );
    
    return Card(
      child: Column(
        children: [
          Text("Status: Persetujuan Diterima ✓"),
          Text("Waktu Bayar: ${timeLeft.inMinutes} menit lagi"),
          ElevatedButton(
            onPressed: _openPaymentScreen,
            child: Text("Upload Bukti Pembayaran"),
          ),
        ],
      ),
    );
  }
  
  if (queue.requestStatus == RequestStatus.rejected) {
    return Card(
      color: Colors.red.shade100,
      child: Column(
        children: [
          Text("Status: Persetujuan Ditolak ✗", style: TextStyle(color: Colors.red)),
          Text("Alasan: ${queue.rejectionReason}"),
          ElevatedButton(
            onPressed: _openNewRequest,
            child: Text("Ajukan Booking Baru"),
          ),
        ],
      ),
    );
  }
}
```

#### Screen: payment_screen.dart
```dart
// MODIFIKASI: Sekarang hanya menerima queue dengan status "booked"
// (yang sudah diapprove admin)

void _onPaymentScreenOpen() {
  // Validasi: queue harus sudah approved
  if (queue.requestStatus != RequestStatus.approved) {
    showDialog(context, "Booking belum diapprove admin");
    return;
  }
  
  // Cek payment deadline tidak melebihi
  if (DateTime.now().isAfter(queue.paymentDeadline!.toDate())) {
    // Handle timeout di sini atau biarkan timeout handler
    showDialog(context, "Waktu pembayaran sudah habis");
    return;
  }
  
  // OLD flow: upload payment & submit
  // NEW: sama seperti sebelumnya, hanya tinggal upload
}
```

### Admin Side Flow

#### Screen: admin_dashboard.dart (BARU - Request Approval Panel)
```dart
// NEW: Tab untuk "Lihat Request Booking Menunggu"

class _PendingRequestsPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('queues')
          .where('request_status', isEqualTo: 'pending')
          .orderBy('booking_time', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final requests = snapshot.data?.docs
            .map((doc) => Queue.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>))
            .toList() ?? [];
        
        return ListView(
          children: requests.map((request) {
            return _buildRequestCard(request);
          }).toList(),
        );
      },
    );
  }
  
  Widget _buildRequestCard(Queue request) {
    return Card(
      child: Column(
        children: [
          Text("Customer: ${request.customerId}"),
          Text("Barbershop: ${request.barbershopId}"),
          Text("Tanggal: ${request.bookingTime.toDate()}"),
          
          // Tombol approve/reject
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _approveRequest(request),
                child: Text("✓ Approve"),
              ),
              ElevatedButton(
                onPressed: () => _rejectRequest(request),
                child: Text("✗ Reject"),
              ),
            ],
          ),
          
          // Jika mau reject, tampilkan text field untuk alasan
          if (_isEditingReason[request.id] == true)
            TextField(
              onChanged: (val) => _rejectionReason[request.id] = val,
              placeholder: "Alasan penolakan",
            ),
        ],
      ),
    );
  }
  
  void _approveRequest(Queue request) async {
    // Update queue status
    await FirebaseFirestore.instance
        .collection('queues')
        .doc(request.id)
        .update({
          'request_status': 'approved',
          'status': 'booked',  // berubah dari waiting ke booked
          'payment_deadline': Timestamp.fromDate(
            DateTime.now().add(Duration(hours: 1)),
          ),
        });
    
    // Send notification ke customer:
    // "Booking Anda disetujui. Silakan upload bukti pembayaran dalam 1 jam"
  }
  
  void _rejectRequest(Queue request) async {
    // Ambil alasan dari text field
    String reason = _rejectionReason[request.id] ?? "Tidak ada keterangan";
    
    await FirebaseFirestore.instance
        .collection('queues')
        .doc(request.id)
        .update({
          'request_status': 'rejected',
          'status': 'cancelled',
          'rejection_reason': reason,
        });
    
    // Send notification ke customer:
    // "Booking Anda ditolak. Alasan: $reason"
  }
}
```

#### Screen: live_queue_screen.dart (MODIFIKASI)
```dart
// OLD: Menampilkan semua queue dengan status 'booked', 'ongoing', 'served'
// NEW: Tambah filter untuk hanya tampilkan yang sudah approved payment

// Filter: tampilkan hanya queue dengan status 'ongoing' atau 'served'
// (yang sudah lulus approval admin + payment verification)
```

---

## 6. AI Model Integration (StyleScan & ChatBot)

### 🚫 JANGAN Buat AI Model
Kamu TIDAK perlu membuat atau training model AI sendiri. Model milikmu sudah di VPS.

### ✅ Yang Perlu Dibuat: API Configuration

Buat sistem untuk **memudahkan configure API endpoint** milikmu:

#### File Baru: `lib/services/ai_config_service.dart`

```dart
/// Service untuk manage AI API configuration
/// Customer model sudah ada di VPS server sendiri
/// Service ini hanya handle: Store endpoint, Send request ke API

class AIConfigService {
  // Simpan di shared preferences atau Firebase Settings
  
  // StyleScan Configuration
  String? styleScandisplayName = "StyleScan Hair Detection";
  String? styleScanApiUrl = "https://your-vps.com/api/stylescan";
  String? styleScanApiKey = "your-api-key-123";
  
  // ChatBot Configuration
  String? chatBotDisplayName = "AI Assistant";
  String? chatBotApiUrl = "https://your-vps.com/api/chatbot";
  String? chatBotApiKey = "your-api-key-456";
  
  /// Update StyleScan API Config
  Future<void> updateStyleScanConfig({
    required String apiUrl,
    required String apiKey,
  }) async {
    // Simpan ke shared preferences atau Firebase
    styleScanApiUrl = apiUrl;
    styleScanApiKey = apiKey;
  }
  
  /// Update ChatBot API Config
  Future<void> updateChatBotConfig({
    required String apiUrl,
    required String apiKey,
  }) async {
    chatBotApiUrl = apiUrl;
    chatBotApiKey = apiKey;
  }
  
  /// Call StyleScan API (POST image)
  /// Input: Image file
  /// Output: Detection result dari model
  Future<Map<String, dynamic>> detectHairStyle(File imageFile) async {
    // Validate config exists
    if (styleScanApiUrl == null || styleScanApiUrl!.isEmpty) {
      throw Exception("StyleScan API tidak dikonfigurasi");
    }
    
    // Convert image ke base64
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    
    // Call API
    final response = await http.post(
      Uri.parse(styleScanApiUrl!),
      headers: {
        'Authorization': 'Bearer $styleScanApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'image': base64Image,
      }),
    );
    
    if (response.statusCode == 200) {
      return jsonDecode(response.body); // {"style": "Modern", "confidence": 0.95}
    } else {
      throw Exception("StyleScan API error: ${response.statusCode}");
    }
  }
  
  /// Call ChatBot API (POST query)
  /// Input: User message
  /// Output: AI response
  Future<String> askChatBot(String userMessage) async {
    // Validate config
    if (chatBotApiUrl == null || chatBotApiUrl!.isEmpty) {
      throw Exception("ChatBot API tidak dikonfigurasi");
    }
    
    // Call API
    final response = await http.post(
      Uri.parse(chatBotApiUrl!),
      headers: {
        'Authorization': 'Bearer $chatBotApiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': userMessage,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['response']; // AI response text
    } else {
      throw Exception("ChatBot API error: ${response.statusCode}");
    }
  }
}
```

#### UI untuk Config (Admin Settings)

```dart
/// Screen: admin_settings.dart (NEW)
class AIConfigScreen extends StatefulWidget {
  @override
  State<AIConfigScreen> createState() => _AIConfigScreenState();
}

class _AIConfigScreenState extends State<AIConfigScreen> {
  late TextEditingController styleScanUrlCtrl;
  late TextEditingController styleScanKeyCtrl;
  late TextEditingController chatBotUrlCtrl;
  late TextEditingController chatBotKeyCtrl;
  
  @override
  void initState() {
    super.initState();
    
    // Load existing config
    final aiService = AIConfigService();
    styleScanUrlCtrl = TextEditingController(text: aiService.styleScanApiUrl);
    styleScanKeyCtrl = TextEditingController(text: aiService.styleScanApiKey);
    chatBotUrlCtrl = TextEditingController(text: aiService.chatBotApiUrl);
    chatBotKeyCtrl = TextEditingController(text: aiService.chatBotApiKey);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Konfigurasi AI Models")),
      body: ListView(
        padding: EdgeInsets.all(16),
        children: [
          // StyleScan Section
          Card(
            child: Column(
              children: [
                Text("🎨 StyleScan Hair Detection"),
                TextField(
                  controller: styleScanUrlCtrl,
                  decoration: InputDecoration(
                    labelText: "API URL",
                    hintText: "https://your-vps.com/api/stylescan",
                  ),
                ),
                TextField(
                  controller: styleScanKeyCtrl,
                  decoration: InputDecoration(
                    labelText: "API Key",
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // ChatBot Section
          Card(
            child: Column(
              children: [
                Text("🤖 AI ChatBot Assistant"),
                TextField(
                  controller: chatBotUrlCtrl,
                  decoration: InputDecoration(
                    labelText: "API URL",
                    hintText: "https://your-vps.com/api/chatbot",
                  ),
                ),
                TextField(
                  controller: chatBotKeyCtrl,
                  decoration: InputDecoration(
                    labelText: "API Key",
                  ),
                  obscureText: true,
                ),
              ],
            ),
          ),
          
          SizedBox(height: 16),
          
          // Save Button
          ElevatedButton(
            onPressed: _saveConfig,
            child: Text("💾 Simpan Konfigurasi"),
          ),
        ],
      ),
    );
  }
  
  void _saveConfig() async {
    final aiService = AIConfigService();
    
    await aiService.updateStyleScanConfig(
      apiUrl: styleScanUrlCtrl.text,
      apiKey: styleScanKeyCtrl.text,
    );
    
    await aiService.updateChatBotConfig(
      apiUrl: chatBotUrlCtrl.text,
      apiKey: chatBotKeyCtrl.text,
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✓ Konfigurasi berhasil disimpan")),
    );
  }
}
```

#### Menggunakan StyleScan di Screen

```dart
/// Screen: stylescan_screen.dart (MODIFIKASI)
class _StyleScanScreenState extends State<StyleScanScreen> {
  final AIConfigService _aiService = AIConfigService();
  
  void _pickImageAndAnalyze() async {
    // Pick image dari gallery
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image == null) return;
    
    try {
      // Call API ke model mu
      final result = await _aiService.detectHairStyle(File(image.path));
      
      // Tampilkan hasil
      setState(() {
        detectedStyle = result['style'];
        confidence = result['confidence'];
      });
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error: $e")),
      );
    }
  }
}
```

#### Menggunakan ChatBot di Screen

```dart
/// Screen: chat_assistant_screen.dart (MODIFIKASI)
class _ChatAssistantScreenState extends State<ChatAssistantScreen> {
  final AIConfigService _aiService = AIConfigService();
  final List<ChatMessage> messages = [];
  
  void _sendMessage(String userMessage) async {
    // Add user message ke UI
    setState(() {
      messages.add(ChatMessage(
        text: userMessage,
        isUser: true,
        timestamp: DateTime.now(),
      ));
    });
    
    try {
      // Call API ke model mu
      final response = await _aiService.askChatBot(userMessage);
      
      // Add AI response ke UI
      setState(() {
        messages.add(ChatMessage(
          text: response,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
      
    } catch (e) {
      setState(() {
        messages.add(ChatMessage(
          text: "❌ Error: $e",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
  }
}
```

---

## 7. Cloud Functions (Automated Payment Timeout)

Buat Cloud Function untuk auto-cancel booking jika customer tidak bayar dalam 1 jam:

### File: `functions/src/index.ts` (atau Node.js)

```typescript
import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';

admin.initializeApp();

/**
 * Cloud Function: Cancel expired booking requests
 * Trigger: setiap 5 menit cek apakah ada payment deadline yang sudah lewat
 * Action: Auto-cancel booking dengan rejection_reason "Payment timeout"
 */
export const cancelExpiredPayments = functions
  .pubsub.schedule('every 5 minutes')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    
    // Cari queue dengan:
    // - request_status: 'approved'
    // - status: 'booked' (belum bayar)
    // - payment_deadline: sudah lewat
    const expiredBookings = await db.collection('queues')
      .where('request_status', '==', 'approved')
      .where('status', '==', 'booked')
      .where('payment_deadline', '<', now)
      .get();
    
    console.log(`Found ${expiredBookings.docs.length} expired bookings`);
    
    // Update setiap booking yang expired
    const batch = db.batch();
    
    for (const doc of expiredBookings.docs) {
      batch.update(doc.ref, {
        status: 'cancelled',
        rejection_reason: 'Payment timeout (exceeded payment deadline)',
      });
      
      // Kirim notif ke customer
      const queue = doc.data();
      await sendNotification(queue.customer_id, {
        title: 'Booking Dibatalkan',
        body: 'Waktu pembayaran sudah habis. Silakan ajukan booking baru.',
      });
    }
    
    await batch.commit();
    console.log(`Cancelled ${expiredBookings.docs.length} expired bookings`);
  });

async function sendNotification(userId: string, payload: any) {
  // Implement Firebase Cloud Messaging (FCM) notification
  // Atau bisa pakai Firestore to store pending notifications
}
```

---

## 8. Step-by-Step Implementation Checklist

### Phase 3 (Sekarang):
- [x] Update Queue model dengan RequestStatus enum & new fields
- [x] Create dokumentasi alur booking baru
- [ ] Update appointment_screen.dart untuk request booking flow
- [ ] Update my_bookings_screen.dart untuk tampilkan request status
- [ ] Update admin_dashboard.dart untuk approval panel
- [ ] Create AIConfigService untuk API configuration
- [ ] Update stylescan_screen.dart untuk call API
- [ ] Update chat_assistant_screen.dart untuk call API

### Phase 4:
- [ ] Deploy Cloud Function untuk auto-cancel expired payments
- [ ] Setup Firebase Cloud Messaging (FCM) untuk notifikasi
- [ ] Create admin settings screen untuk configure AI APIs
- [ ] Test full booking flow end-to-end

### Phase 5:
- [ ] Unit tests untuk new booking flow
- [ ] Integration tests untuk payment timeout
- [ ] Load testing untuk concurrent requests

---

## 9. API Contracts (Untuk VPS Mu)

### StyleScan API
```
POST /api/stylescan

Request Body:
{
  "image": "base64-encoded-image-data",
  "options": {
    "return_confidence": true,
    "return_top_3": true
  }
}

Response (200 OK):
{
  "status": "success",
  "detection": {
    "style": "Modern Undercut",
    "confidence": 0.94,
    "top_3_styles": [
      {"style": "Modern Undercut", "confidence": 0.94},
      {"style": "Fade", "confidence": 0.04},
      {"style": "Pompadour", "confidence": 0.02}
    ]
  }
}

Error Response (400/500):
{
  "status": "error",
  "message": "Image processing failed: ..."
}
```

### ChatBot API
```
POST /api/chatbot

Request Body:
{
  "message": "Saya ingin potong rambut modern",
  "user_id": "customer-123",
  "context": {
    "barbershop_id": "shop-456",
    "user_history": []
  }
}

Response (200 OK):
{
  "status": "success",
  "response": "Potong modern itu bagus! Modern undercut sangat cocok untuk...",
  "suggestions": [
    "Lihat referensi di StyleScan",
    "Konsultasi dengan barber"
  ]
}

Error Response:
{
  "status": "error",
  "message": "..."
}
```

---

## 10. Testing Dengan Postman

Sebelum integrate ke app, test API milikmu di Postman:

### StyleScan Test
```
POST https://your-vps.com/api/stylescan
Headers:
  Authorization: Bearer your-api-key-123
  Content-Type: application/json

Body (raw JSON):
{
  "image": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg=="
}
```

### ChatBot Test
```
POST https://your-vps.com/api/chatbot
Headers:
  Authorization: Bearer your-api-key-456
  Content-Type: application/json

Body (raw JSON):
{
  "message": "Barber mana yang bagus untuk pemula?",
  "user_id": "test-customer",
  "context": {}
}
```

---

## 11. Troubleshooting

### Issue: "Booking request tidak muncul di admin dashboard"
**Solusi:**
- Cek apakah `request_status` field ada di Firestore
- Cek firestore rules apakah admin punya akses baca ke collection `queues`

### Issue: "Payment timeout tidak jalan"
**Solusi:**
- Deploy Cloud Function dulu (belum ada di Phase 3)
- Cek apakah `payment_deadline` di-set saat admin approve
- Monitor Cloud Function logs di Firebase Console

### Issue: "API call error 401 Unauthorized"
**Solusi:**
- Cek API key di settings (apakah benar copy-paste)
- Pastikan API key tidak expired di VPS
- Test API manually dulu dengan Postman

---

## 12. Summary

| Aspek | Deskripsi |
|-------|-----------|
| **New Approval Flow** | Request → Approve/Reject → Payment → Verify |
| **Status Tracking** | QueueStatus + RequestStatus untuk tracking lengkap |
| **Database** | 5 field baru untuk new flow (requestStatus, paymentDeadline, dll) |
| **AI Integration** | Jangan buat model, cukup API config untuk model milikmu |
| **Payment Timeout** | Auto-cancel via Cloud Function setiap 5 menit |
| **Admin Panel** | NEW tab untuk approve/reject request booking |
| **Customer UX** | Lebih aman, tidak ada money risk sebelum approved |

---

**Last Updated:** 17 Nov 2025  
**Status:** Ready untuk Phase 3 Implementation  
**Next:** Mulai update screens (appointment_screen, my_bookings_screen, admin_dashboard)

