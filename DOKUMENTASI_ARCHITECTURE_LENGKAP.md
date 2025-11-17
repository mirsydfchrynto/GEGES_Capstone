# DOKUMENTASI LENGKAP ARCHITECTURE & FLOW

## Overview Aplikasi GEGES SmartBarber

GEGES SmartBarber adalah aplikasi mobile booking barbershop dengan fitur:
- Customer dapat booking appointment online
- Admin/owner dapat manage live queue dan bookings
- Real-time updates dengan Firestore
- Payment verification dengan bukti upload
- AI chatbot untuk rekomendasi

---

## 1. ARCHITECTURE PATTERN

### MVC (Model-View-Controller) Architecture

```
┌─────────────────────────────────────────────────────┐
│                  UI LAYER (Views)                    │
├─────────────────────────────────────────────────────┤
│ LoginScreen | HomeScreen | AppointmentScreen        │
│ PaymentScreen | AdminDashboard | LiveQueueScreen    │
│ ProfileScreen | BarbershopDetailScreen | etc.       │
└────────────────────┬────────────────────────────────┘
                     │ (uses services)
┌────────────────────▼────────────────────────────────┐
│              SERVICE LAYER (Controllers)             │
├─────────────────────────────────────────────────────┤
│ AuthService | BarbershopService | QueueService      │
│ BarbermanService | ServiceService                   │
└────────────────────┬────────────────────────────────┘
                     │ (queries/updates)
┌────────────────────▼────────────────────────────────┐
│               DATA LAYER (Models)                    │
├─────────────────────────────────────────────────────┤
│ Queue | Barbershop | Service | Barberman            │
│ UserData | BookingDetails | PromoBanner             │
└────────────────────┬────────────────────────────────┘
                     │ (persists to)
┌────────────────────▼────────────────────────────────┐
│            FIREBASE BACKEND                         │
├─────────────────────────────────────────────────────┤
│ Firestore (database) | Cloud Storage (files)        │
│ Firebase Auth | Firebase Functions                  │
└─────────────────────────────────────────────────────┘
```

### Layer Separation

**Views (Screens):**
- Hanya handle UI rendering & user interaction
- Call services untuk business logic
- Manage local UI state (form input, loading, etc)

**Services:**
- Menangani business logic & Firebase operations
- Query & update Firestore
- No UI logic di sini
- Return data ke Views

**Models:**
- Represent data structures
- Factory constructor untuk Firestore conversion
- toJson() untuk serialization
- Immutable (final properties)

---

## 2. BOOKING FLOW

### Customer Booking Journey

```
1. ONBOARDING (First Launch)
   OnboardingScreen
   └─ Show 3 intro slides
   └─ Skip/Next → LoginScreen

2. AUTH
   LoginScreen
   ├─ Email + Password
   ├─ Google Sign-In
   └─ Navigate by role (customer/admin)
   
   OR RegisterScreen
   ├─ Create new account
   ├─ Create user doc in Firestore
   └─ Send email verification
   └─ Go to LoginScreen

3. HOME
   HomeScreen (4 tabs)
   ├─ Home Tab
   │  ├─ Promo Carousel (real-time from Firestore)
   │  └─ Barbershop List (FutureBuilder)
   │     └─ Tap barbershop → BarbershopDetailScreen
   │
   ├─ StyleScan Tab (AI hairstyle recommendation)
   ├─ Chatbot Tab (AI assistant)
   └─ Profile Tab
      ├─ View profile info
      ├─ Edit profile button
      ├─ My bookings button
      ├─ Favorites button
      └─ Logout button

4. BARBERSHOP DETAIL
   BarbershopDetailScreen
   ├─ 3 Tabs:
   │  ├─ About (jam, alamat, rating)
   │  ├─ Services (daftar layanan & harga)
   │  └─ Reviews (ulasan customer)
   ├─ Favorite button
   └─ Book Appointment button
      └─ Navigate to AppointmentScreen

5. APPOINTMENT
   AppointmentScreen
   ├─ Select services (multi-select)
   ├─ Select barberman (from barbershop)
   ├─ Select date & time (with time picker)
   ├─ Calculate:
   │  ├─ Total price (sum dari services)
   │  ├─ Total duration (sum dari services)
   │  └─ Estimated finish time
   ├─ Check slot availability
   └─ Confirm booking button
      └─ Create Queue in Firestore (status: waiting)
      └─ Navigate to PaymentScreen

6. PAYMENT
   PaymentScreen
   ├─ Show order summary
   ├─ Display countdown timer (10 min)
   ├─ Image picker (camera/gallery)
   ├─ Upload bukti pembayaran
   │  ├─ Convert to base64
   │  ├─ Upload to Firebase Storage
   │  └─ Save URL di Firestore
   ├─ Update Queue status: waiting → booked
   └─ Navigate to confirmation screen

7. CONFIRMATION
   BookingConfirmationScreen
   ├─ Show "booking confirmed" message
   ├─ Display booking details
   └─ Option to view bookings atau back to home
```

### Admin (Owner) Workflow

```
1. LOGIN
   LoginScreen
   ├─ Email + Password (admin account)
   ├─ Fetch UserData (check role: admin_owner)
   └─ Navigate to AdminDashboardScreen

2. DASHBOARD
   AdminDashboardScreen
   ├─ Display barbershop info
   ├─ Toggle open/closed status
   ├─ Show stats (upcoming bookings, revenue, etc)
   └─ Quick action buttons:
      ├─ Live Queue button → LiveQueueScreen
      └─ Add Manual Booking button → AddManualBookingScreen

3. LIVE QUEUE
   LiveQueueScreen
   ├─ Real-time queue list (StreamBuilder)
   ├─ Filter by status (waiting, booked, ongoing, served, cancelled)
   ├─ For each queue:
   │  ├─ Show QueueCard widget
   │  ├─ Display customer, barberman, service info
   │  └─ Action buttons:
   │     ├─ Confirm (waiting → booked)
   │     ├─ Start (booked → ongoing)
   │     ├─ Finish (ongoing → served)
   │     └─ Cancel (any status → cancelled)
   └─ Real-time updates (auto-refresh on changes)

4. ADD MANUAL BOOKING
   AddManualBookingScreen
   ├─ Select customer
   ├─ Select barberman
   ├─ Select service
   ├─ Select date & time
   └─ Create booking (status: booked directly)
      └─ Create Queue in Firestore
      └─ Back to LiveQueueScreen
```

---

## 3. DATA MODELS & FIRESTORE STRUCTURE

### Firestore Collections

```
project-firebase
├─ users/
│  ├─ {uid}
│  │  ├─ name: string
│  │  ├─ email: string
│  │  ├─ role: 'customer' | 'admin_owner'
│  │  ├─ phone_number: string
│  │  ├─ barbershop_id: string (for admin_owner)
│  │  ├─ favoriteBarbershops: array<string>
│  │  └─ created_at: timestamp
│  
├─ barbershops/
│  ├─ {barbershop_id}
│  │  ├─ name: string
│  │  ├─ address: string
│  │  ├─ rating: double
│  │  ├─ imageUrl: string
│  │  ├─ services: array<string> (service ids)
│  │  ├─ open_hour: int (0-23)
│  │  ├─ close_hour: int (0-23)
│  │  ├─ isOpen: boolean
│  │  └─ created_at: timestamp
│  
├─ services/
│  ├─ {service_id}
│  │  ├─ name: string
│  │  ├─ description: string
│  │  ├─ price: double
│  │  ├─ default_duration: int (minutes)
│  │  ├─ isActive: boolean
│  │  └─ created_at: timestamp
│  
├─ barbermen/
│  ├─ {barberman_id}
│  │  ├─ name: string
│  │  ├─ barbershop_id: string
│  │  ├─ imageUrl: string
│  │  ├─ avg_duration: int (minutes)
│  │  ├─ rating: double
│  │  ├─ isActive: boolean
│  │  └─ created_at: timestamp
│  
├─ queues/
│  ├─ {queue_id}
│  │  ├─ customer_id: string
│  │  ├─ barbershop_id: string
│  │  ├─ barberman_id: string
│  │  ├─ service_ids: array<string>
│  │  ├─ booking_time: timestamp
│  │  ├─ status: 'waiting' | 'booked' | 'ongoing' | 'served' | 'cancelled'
│  │  ├─ total_price: int
│  │  ├─ estimated_duration: int (minutes)
│  │  ├─ start_time: timestamp (optional)
│  │  ├─ finish_time: timestamp (optional)
│  │  ├─ payment_image_url: string (optional)
│  │  ├─ payment_submitted_at: timestamp (optional)
│  │  ├─ created_at: timestamp
│  │  └─ updated_at: timestamp
│  
├─ reviews/
│  ├─ {review_id}
│  │  ├─ barbershop_id: string
│  │  ├─ customer_id: string
│  │  ├─ rating: double (1-5)
│  │  ├─ comment: string
│  │  ├─ created_at: timestamp
│  
├─ promos/
│  ├─ {promo_id}
│  │  ├─ title: string
│  │  ├─ subtitle: string
│  │  ├─ imageUrl: string
│  │  ├─ isActive: boolean
│  │  └─ created_at: timestamp
```

### Model Relationships

```
User
├─ hasMany: Queue (1 customer bisa punya many bookings)
├─ hasMany: Review (1 customer bisa punya many reviews)
└─ favorites: array<Barbershop>

Queue
├─ belongsTo: User (customer)
├─ belongsTo: Barbershop
├─ belongsTo: Barberman
└─ hasMany: Service (1 queue bisa punya multiple services)

Barbershop
├─ hasMany: Queue
├─ hasMany: Barberman
├─ hasMany: Service
└─ hasMany: Review

Barberman
├─ belongsTo: Barbershop
├─ hasMany: Queue

Service
├─ belongsTo: Barbershop
└─ hasMany: Queue (many-to-many via queue)

Review
├─ belongsTo: Barbershop
└─ belongsTo: User (customer)
```

---

## 4. STATE MANAGEMENT

### Local State (setState)
Screens yang manage local UI state dengan setState:
- LoginScreen - form input, error message, loading
- RegisterScreen - form validation, password confirm
- AppointmentScreen - selected services, date, time, availability
- PaymentScreen - selected image, countdown timer
- ProfileScreen - profile data display
- AdminDashboardScreen - shop status toggle

### Async State (FutureBuilder/StreamBuilder)
Screens yang fetch data dari Firebase:
- HomeScreen - barbershop list (Future)
- BarbershopDetailScreen - review count (Future), favorite status (Future)
- MyBookingsScreen - user bookings (Stream)
- LiveQueueScreen - queue list (Stream)

### Data Pattern
```
Screen
├─ StateManager (Local): setState() untuk UI interaction
├─ FutureBuilder: untuk fetch single-time data
└─ StreamBuilder: untuk real-time updates

Services
├─ Query Firestore (synchronous)
└─ Return data ke Screen

Models
├─ fromFirestore(): convert firestore doc to model
└─ toJson(): convert model to JSON untuk save
```

---

## 5. NAVIGATION STRUCTURE

### Named Routes vs Direct Navigation
App menggunakan **direct navigation** (MaterialPageRoute) bukan named routes.

```dart
// Direct navigation
Navigator.of(context).push(
  MaterialPageRoute(
    builder: (context) => const TargetScreen(),
  ),
);

// Push with replacement
Navigator.of(context).pushReplacement(...);

// Pop
Navigator.of(context).pop();

// Pop and remove all
Navigator.of(context).pushAndRemoveUntil(...);
```

### Navigation Map

```
LoginScreen
├─ Register link → RegisterScreen
│  └─ Back to LoginScreen
│
├─ Successful login (customer) → HomeScreen
│
├─ Successful login (admin) → AdminDashboardScreen
│
└─ Google Sign-In → HomeScreen/AdminDashboardScreen

HomeScreen (4 tabs)
├─ Home Tab
│  ├─ Barbershop → BarbershopDetailScreen
│  │  └─ Book button → AppointmentScreen
│  │     └─ Confirm → PaymentScreen
│  │        └─ Success → ConfirmationScreen
│  │
│  └─ Favorite icon → Add to favorites
│
├─ StyleScan Tab
├─ Chatbot Tab
└─ Profile Tab
   ├─ Edit Profile → EditProfileScreen
   ├─ My Bookings → MyBookingsScreen
   ├─ Favorites → FavoriteBarbershopsScreen
   └─ Logout → LoginScreen

AdminDashboardScreen
├─ Live Queue → LiveQueueScreen
│  └─ Queue actions (start, finish, cancel)
│
└─ Add Manual Booking → AddManualBookingScreen
```

---

## 6. FIREBASE INTEGRATION

### Authentication
- Firebase Auth untuk user login/register
- Google Sign-In untuk oauth
- Email verification untuk new accounts
- Password reset (optional)

### Database (Firestore)
- Real-time listeners (StreamBuilder)
- Single document queries (FutureBuilder)
- Transactions untuk atomic operations
- Security rules untuk permission

### Storage (Cloud Storage)
- Upload payment proofs
- Store barbershop images
- Store promo images

---

## 7. KEY DESIGN PATTERNS

### Factory Pattern (Models)
```dart
factory Queue.fromFirestore(DocumentSnapshot doc) {
  // convert firestore document ke dart object
  // handle field name variations
  // provide default values
}

Queue.toJson() {
  // convert model to JSON untuk firestore
}
```

### Service Locator Pattern
```dart
// di screen, create service instance
final QueueService _queueService = QueueService();

// use di methods
await _queueService.createQueue(queue);
```

### Stream Pattern (Real-time)
```dart
// di service
Stream<List<Queue>> streamQueuesForCustomer(String customerId) {
  return firestore
      .collection('queues')
      .where('customer_id', isEqualTo: customerId)
      .snapshots()
      .map((snapshot) => ...);
}

// di screen (StreamBuilder)
StreamBuilder<List<Queue>>(
  stream: queueService.streamQueuesForCustomer(userId),
  builder: (context, snapshot) { ... }
)
```

### Callback Pattern (User Actions)
```dart
// di widget
final FutureOr<void> Function()? onStartService;

// di parent screen
QueueCard(
  queue: queue,
  onStartService: () async {
    await queueService.startService(queue.id);
  },
)
```

---

## 8. ERROR HANDLING & VALIDATION

### Input Validation
```dart
// email validation
if (email.isEmpty) {
  setState(() => _errorMessage = 'email wajib diisi');
  return;
}

// password strength
if (password.length < 6) {
  setState(() => _errorMessage = 'password minimal 6 karakter');
  return;
}

// form validation
if (!_formKey.currentState!.validate()) {
  return;
}
```

### Exception Handling
```dart
try {
  // firebase operation
  await firestore.collection('queues').add(queue.toJson());
} on FirebaseAuthException catch (e) {
  // handle firebase auth errors
} catch (e) {
  // handle general errors
  debugPrint("error: $e");
}
```

### Loading & Error States
```dart
// FutureBuilder
FutureBuilder<List<Barbershop>>(
  future: future,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return LoadingWidget();  // loading state
    }
    if (snapshot.hasError) {
      return Text('error: ${snapshot.error}');  // error state
    }
    return buildList(snapshot.data);  // success state
  }
)
```

---

## 9. BEST PRACTICES IMPLEMENTED

✅ **Separation of Concerns** - Views, Services, Models terpisah
✅ **Null Safety** - Using ? dan ! operator dengan bijak
✅ **Resource Cleanup** - dispose() controllers dan streams
✅ **Error Handling** - try-catch dengan specific errors
✅ **Loading States** - disable buttons saat loading
✅ **Type Safety** - strong typing di models
✅ **Immutability** - final properties di models
✅ **Documentation** - komentar untuk code clarity
✅ **DRY Principle** - reusable widgets & services
✅ **Permission Handling** - request camera/gallery permissions

---

## 10. QUICK START GUIDE

### Setup Project
```bash
flutter pub get
firebase login
flutterfire configure
```

### Key Files to Edit
1. `main.dart` - Firebase init, theme setup
2. `lib/models/*.dart` - Data models
3. `lib/services/*.dart` - Business logic
4. `lib/screens/*.dart` - UI screens
5. `lib/widgets/*.dart` - Reusable components

### Common Tasks

**Add New Feature:**
1. Create model in `lib/models/`
2. Create service methods in `lib/services/`
3. Create screen in `lib/screens/`
4. Use service in screen
5. Add navigation link

**Add Real-time Updates:**
1. Create Stream method di service
2. Use StreamBuilder di screen
3. Build UI dari snapshot.data

**Handle User Interaction:**
1. Create callback parameter
2. Pass function reference dari parent
3. Call function saat button pressed

---

## Summary

**GEGES SmartBarber** adalah aplikasi booking yang:
- Menggunakan **MVC architecture** untuk separation of concerns
- Leverage **Firebase** untuk authentication & real-time database
- Implement **reusable widgets** & services untuk code efficiency
- Handle **async operations** dengan Future/Stream patterns
- Provide **real-time updates** dengan Firestore listeners
- Support **multiple user roles** (customer & admin)
- Include **error handling** & validation di setiap layer

Dokumentasi lengkap ada di folder `DOKUMENTASI_*.md` files.

