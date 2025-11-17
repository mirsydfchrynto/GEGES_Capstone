# DOKUMENTASI AUTH & AUTH SCREENS

## Pengantar
Auth flows adalah proses login, register, dan onboarding yang memastikan user masuk dengan credentials yang benar. Di aplikasi GEGES, ada 3 screen: OnboardingScreen, LoginScreen, dan RegisterScreen.

---

## 1. onboarding_screen.dart

### Deskripsi
OnboardingScreen menampilkan carousel dengan 3 halaman pengenalan aplikasi sebelum user masuk ke login. Hanya ditampilkan pada first launch (menggunakan SharedPreferences).

### Features
- PageView dengan 3 halaman (carousel)
- Indicator dots untuk tampilkan halaman saat ini
- Skip button untuk langsung ke login
- Next button untuk navigate halaman berikutnya
- Get Started button di halaman terakhir

### Struktur Code

```dart
// =====================================================
// CONSTANTS & THEME
// =====================================================
const Color kBrownAccent = Color(0xFFC3A47B);  // warna accent untuk button dan indicator
const Color kBackgroundColor = Colors.black;   // background hitam sesuai design

// penjelasan:
// - const berarti constant (tidak berubah)
// - disimpan di level file untuk akses global


// =====================================================
// MAIN WIDGET
// =====================================================
class OnboardingScreen extends StatefulWidget {
  // stateful karena perlu track state:
  // - halaman saat ini (_currentPage)
  // - controller untuk pageview (_pageController)
  
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}
```

### State Class

```dart
class _OnboardingScreenState extends State<OnboardingScreen> {
  // =====================================================
  // PAGE CONTROLLER (untuk navigasi halaman)
  // =====================================================
  final PageController _pageController = PageController(initialPage: 0);
  // penjelasan:
  // - PageController untuk control PageView
  // - initialPage: 0 = mulai dari halaman pertama
  // - bisa di-dispose untuk cleanup

  // =====================================================
  // STATE TRACKING
  // =====================================================
  int _currentPage = 0;
  // penjelasan:
  // - track halaman mana yang sedang ditampilkan
  // - diupdate saat user swipe atau klik next
  // - digunakan untuk highlight dot indicator yang benar

  // =====================================================
  // ONBOARDING DATA (3 halaman)
  // =====================================================
  final List<Map<String, String>> _onboardingData = [
    {
      "image": "assets/images/onboarding_clock.png",
      "title": "say goodbye to long waits",
      "subtitle": "book your spot in advance with geges and arrive just in time for your haircut."
    },
    {
      "image": "assets/images/onboarding_pin.png",
      "title": "find nearby barbers",
      "subtitle": "discover the best barbershops in your area with ratings and reviews from real customers."
    },
    {
      "image": "assets/images/onboarding_bot.png",
      "title": "smart assistant",
      "subtitle": "get personalized recommendations and instant booking help through our ai chatbot."
    }
  ];
  // penjelasan:
  // - list of maps, setiap map = 1 halaman
  // - "image" = path gambar di assets folder
  // - "title" = headline halaman
  // - "subtitle" = deskripsi di bawah headline
```

### Key Method: _navigateToLogin()

```dart
void _navigateToLogin() {
  // penjelasan:
  // - function ini dipanggil saat user klik skip atau get started
  // - navigasi ke login screen dan hapus onboarding dari stack
  // - alasan hapus: user tidak perlu lihat onboarding lagi

  if (mounted) {  // safety check: widget masih active
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }
}
```

### UI: Build Method

```dart
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.black,  // latar hitam
    body: SafeArea(
      child: Stack(
        children: [
          // =====================================================
          // LAYER 1: PAGE VIEW (CAROUSEL)
          // =====================================================
          PageView.builder(
            controller: _pageController,
            itemCount: _onboardingData.length,  // 3 halaman
            onPageChanged: (int page) {
              // penjelasan:
              // - dipanggil setiap kali user swipe ke halaman baru
              // - update _currentPage state untuk update indicator dots
              setState(() {
                _currentPage = page;
              });
            },
            itemBuilder: (context, index) {
              // penjelasan:
              // - builder function untuk create 1 page
              // - index = halaman mana yang di-build (0, 1, atau 2)
              // - return widget yang merepresentasikan 1 onboarding page
              return _buildPageContent(_onboardingData[index]);
            },
          ),

          // =====================================================
          // LAYER 2: SKIP BUTTON (TOP RIGHT)
          // =====================================================
          Positioned(
            top: 10.0,
            right: 24.0,
            child: TextButton(
              onPressed: _navigateToLogin,  // skip langsung ke login
              child: const Text('skip'),
            ),
          ),

          // =====================================================
          // LAYER 3: NAVIGATION CONTROLS (BOTTOM)
          // =====================================================
          Positioned(
            bottom: 40.0,
            left: 24.0,
            right: 24.0,
            child: Column(
              children: [
                // indicator dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: _buildPageIndicator(),
                ),
                const SizedBox(height: 40.0),

                // next / get started button
                ElevatedButton(
                  onPressed: () {
                    if (_currentPage == _onboardingData.length - 1) {
                      // di halaman terakhir, navigasi ke login
                      _navigateToLogin();
                    } else {
                      // di halaman lain, swipe ke halaman berikutnya
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  child: Text(
                    _currentPage == _onboardingData.length - 1
                        ? 'get started'
                        : 'next',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
```

### Helper Method: _buildPageIndicator()

```dart
List<Widget> _buildPageIndicator() {
  // penjelasan:
  // - build dots untuk tampilkan halaman saat ini
  // - setiap dot mewakili 1 halaman
  // - dot yang aktif (sesuai _currentPage) berwarna coklat
  // - dot yang tidak aktif berwarna abu-abu

  return List<Widget>.generate(
    _onboardingData.length,  // 3 dots
    (index) => AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: 8,
      width: _currentPage == index ? 24 : 8,  // wider jika active
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: _currentPage == index ? kBrownAccent : Colors.grey,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}
```

### Helper Method: _buildPageContent()

```dart
Widget _buildPageContent(Map<String, String> data) {
  // penjelasan:
  // - build satu halaman onboarding
  // - tampilkan image, title, dan subtitle

  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // image
      Image.asset(
        data['image']!,
        height: 300,
      ),
      const SizedBox(height: 40),

      // title
      Text(
        data['title']!.toUpperCase(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),

      // subtitle
      Text(
        data['subtitle']!,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
        ),
        textAlign: TextAlign.center,
      ),
    ],
  );
}
```

---

## 2. login_screen.dart

### Deskripsi
LoginScreen adalah halaman login untuk user yang sudah punya akun. Input email & password, authenticasi via Firebase, kemudian navigate ke screen sesuai role (customer → HomeScreen, admin_owner → AdminDashboard).

### Features
- Email input field
- Password input field (dengan toggle show/hide)
- Error message display
- Loading state (spinner saat login process)
- Navigasi ke RegisterScreen (untuk user baru)
- Role-based navigation (customer vs admin)

### Struktur Code

```dart
// =====================================================
// CONSTANTS
// =====================================================
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kHintText = Color(0xFF6B6B6B);

// =====================================================
// MAIN WIDGET
// =====================================================
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// =====================================================
// STATE CLASS
// =====================================================
class _LoginScreenState extends State<LoginScreen> {
  // =====================================================
  // FORM CONTROLLERS
  // =====================================================
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  // penjelasan:
  // - TextEditingController untuk manage input field
  // - bisa access value dengan .text
  // - harus di-dispose di method dispose() untuk cleanup

  // =====================================================
  // SERVICE
  // =====================================================
  final AuthService _authService = AuthService();
  // penjelasan:
  // - instance dari auth service untuk handle login logic
  // - service akan call firebase authentication

  // =====================================================
  // UI STATE
  // =====================================================
  String _errorMessage = '';      // error message yg di-display
  bool _isLoading = false;         // loading state saat login process
  bool _obscurePassword = true;    // toggle show/hide password

  @override
  void dispose() {
    // cleanup controllers
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
```

### Key Method: _login()

```dart
void _login() async {
  // penjelasan:
  // - async function untuk handle login process
  // - validasi input → call authService.signIn() → navigate based on role

  // step 1: ambil value dari form
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  // step 2: validasi input tidak kosong
  if (email.isEmpty || password.isEmpty) {
    setState(() => _errorMessage = 'email dan password wajib diisi.');
    return;
  }

  // step 3: set loading state (tampilkan spinner)
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // step 4: call auth service untuk login ke firebase
    final result = await _authService.signIn(
      email: email,
      password: password,
    );

    // step 5: check mount (widget masih active)
    if (!mounted) return;

    // step 6: update loading state
    setState(() => _isLoading = false);

    // step 7: check login result
    if (result['success'] == true) {
      // login berhasil, navigate ke screen sesuai role
      _navigateByRole(result['role']);
    } else {
      // login gagal, tampilkan error message
      setState(() => _errorMessage = result['message'] ?? 'login gagal.');
    }
  } catch (e) {
    // step 8: handle exception
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'terjadi kesalahan: $e';
    });
  }
}
```

### Key Method: _navigateByRole()

```dart
void _navigateByRole(String? role) {
  // penjelasan:
  // - navigate ke screen yang benar berdasarkan user role
  // - 'customer' → HomeScreen (customer mode)
  // - 'admin_owner' → AdminDashboardScreen (admin mode)
  // - unknown role → show error message

  Widget targetScreen;

  if (role == 'customer') {
    targetScreen = const HomeScreen();  // customer dashboard
  } else if (role == 'admin_owner') {
    targetScreen = const AdminDashboardScreen();  // admin dashboard
  } else {
    setState(() => _errorMessage = 'role pengguna tidak valid.');
    return;
  }

  // navigasi ke target screen dengan replace (hapus login dari stack)
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(builder: (context) => targetScreen),
  );
}
```

### UI: Build Method (Form Section)

```dart
// =====================================================
// EMAIL INPUT FIELD
// =====================================================
TextField(
  controller: _emailController,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: 'masukkan email anda',
    hintStyle: const TextStyle(color: kHintText),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: kDarkGrey,
    prefixIcon: const Icon(Icons.email, color: kBrownAccent),
  ),
  keyboardType: TextInputType.emailAddress,
),

// =====================================================
// PASSWORD INPUT FIELD
// =====================================================
TextField(
  controller: _passwordController,
  style: const TextStyle(color: Colors.white),
  obscureText: _obscurePassword,  // toggle show/hide
  decoration: InputDecoration(
    hintText: 'masukkan password anda',
    hintStyle: const TextStyle(color: kHintText),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    filled: true,
    fillColor: kDarkGrey,
    prefixIcon: const Icon(Icons.lock, color: kBrownAccent),
    suffixIcon: IconButton(
      icon: Icon(
        _obscurePassword ? Icons.visibility_off : Icons.visibility,
        color: kBrownAccent,
      ),
      onPressed: () {
        setState(() => _obscurePassword = !_obscurePassword);
      },
    ),
  ),
),

// =====================================================
// LOGIN BUTTON
// =====================================================
ElevatedButton(
  onPressed: _isLoading ? null : _login,  // disable jika loading
  style: ElevatedButton.styleFrom(
    backgroundColor: kBrownAccent,
    minimumSize: const Size(double.infinity, 48),
  ),
  child: _isLoading
      ? const CircularProgressIndicator(color: Colors.black)
      : const Text('login'),
),
```

---

## 3. register_screen.dart

### Deskripsi
RegisterScreen adalah halaman untuk user baru membuat akun. Input nama, email, password, confirmasi password. Terus validasi dan create user di Firebase Auth & Firestore.

### Features
- Name input field
- Email input field
- Password input field
- Confirm password input field
- Password validation (minimal 6 karakter)
- Email verification (optional)
- Navigasi ke LoginScreen setelah register berhasil
- Error message display

### Struktur Code

```dart
// =====================================================
// CONSTANTS
// =====================================================
const Color kBrownAccent = Color(0xFFC3A47B);
const Color kDarkGrey = Color(0xFF1E1E1E);
const Color kHintText = Color(0xFF6B6B6B);

// =====================================================
// MAIN WIDGET
// =====================================================
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

// =====================================================
// STATE CLASS
// =====================================================
class _RegisterScreenState extends State<RegisterScreen> {
  // =====================================================
  // FORM CONTROLLERS
  // =====================================================
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // =====================================================
  // FIREBASE INSTANCES
  // =====================================================
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // =====================================================
  // UI STATE
  // =====================================================
  String _errorMessage = '';
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
```

### Key Method: _register()

```dart
Future<void> _register() async {
  // penjelasan:
  // - async function untuk handle register process
  // - validasi input → buat user di auth → buat user doc di firestore → send email verification

  // step 1: ambil value dari form
  final name = _nameController.text.trim();
  final email = _emailController.text.trim();
  final password = _passwordController.text.trim();
  final confirm = _confirmPasswordController.text.trim();

  // step 2: validasi semua field diisi
  if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
    setState(() => _errorMessage = 'semua field wajib diisi.');
    return;
  }

  // step 3: validasi password & confirm match
  if (password != confirm) {
    setState(() => _errorMessage = 'password dan konfirmasi tidak cocok.');
    return;
  }

  // step 4: validasi password minimal 6 karakter
  if (password.length < 6) {
    setState(() => _errorMessage = 'password minimal 6 karakter.');
    return;
  }

  // step 5: set loading state
  setState(() {
    _isLoading = true;
    _errorMessage = '';
  });

  try {
    // step 6: buat user di firebase auth
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = userCredential.user;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'null-user',
        message: 'gagal membuat akun.',
      );
    }

    // step 7: update display name di firebase auth
    await user.updateDisplayName(name);

    // step 8: buat user document di firestore
    // penjelasan:
    // - setiap user harus punya document di 'users' collection
    // - document id = firebase uid
    // - collection berisi user profile data
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'email': email,
      'role': 'customer',  // default role baru adalah customer
      'created_at': FieldValue.serverTimestamp(),
    });

    // step 9: kirim email verifikasi (optional)
    await user.sendEmailVerification();

    // step 10: navigasi ke login
    if (mounted) {
      Navigator.of(context).pushReplacementNamed(
        '/login',  // atau push ke LoginScreen
      );
    }
  } on FirebaseAuthException catch (e) {
    // handle firebase-specific error
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.message ?? 'register gagal';
      });
    }
  } catch (e) {
    // handle general error
    if (mounted) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'terjadi kesalahan: $e';
      });
    }
  }
}
```

### UI: Build Method (Form Section)

```dart
// =====================================================
// NAME INPUT
// =====================================================
TextField(
  controller: _nameController,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: 'masukkan nama lengkap',
    filled: true,
    fillColor: kDarkGrey,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    prefixIcon: const Icon(Icons.person, color: kBrownAccent),
  ),
),

// =====================================================
// EMAIL INPUT
// =====================================================
TextField(
  controller: _emailController,
  style: const TextStyle(color: Colors.white),
  decoration: InputDecoration(
    hintText: 'masukkan email',
    filled: true,
    fillColor: kDarkGrey,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    prefixIcon: const Icon(Icons.email, color: kBrownAccent),
  ),
  keyboardType: TextInputType.emailAddress,
),

// =====================================================
// PASSWORD INPUT
// =====================================================
TextField(
  controller: _passwordController,
  style: const TextStyle(color: Colors.white),
  obscureText: true,
  decoration: InputDecoration(
    hintText: 'masukkan password (min 6 karakter)',
    filled: true,
    fillColor: kDarkGrey,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    prefixIcon: const Icon(Icons.lock, color: kBrownAccent),
  ),
),

// =====================================================
// CONFIRM PASSWORD INPUT
// =====================================================
TextField(
  controller: _confirmPasswordController,
  style: const TextStyle(color: Colors.white),
  obscureText: true,
  decoration: InputDecoration(
    hintText: 'konfirmasi password',
    filled: true,
    fillColor: kDarkGrey,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    prefixIcon: const Icon(Icons.lock, color: kBrownAccent),
  ),
),

// =====================================================
// REGISTER BUTTON
// =====================================================
ElevatedButton(
  onPressed: _isLoading ? null : _register,
  style: ElevatedButton.styleFrom(
    backgroundColor: kBrownAccent,
    minimumSize: const Size(double.infinity, 48),
  ),
  child: _isLoading
      ? const CircularProgressIndicator(color: Colors.black)
      : const Text('register'),
),
```

---

## Summary

### Auth Flow Diagram
```
OnboardingScreen (first launch only)
    ↓
LoginScreen (atau langsung jika sudah login)
    ├─ "Belum punya akun?" → RegisterScreen
    │   ├─ Validasi input
    │   ├─ Create user di Firebase Auth
    │   ├─ Create user doc di Firestore
    │   └─ Send email verification
    │       ↓
    │   LoginScreen (user login dengan akun baru)
    │
    └─ Email + Password → signIn() via AuthService
        ├─ Validate credentials di Firebase
        ├─ Fetch user role dari Firestore
        └─ Navigate based on role
            ├─ 'customer' → HomeScreen
            └─ 'admin_owner' → AdminDashboardScreen
```

### Best Practices
1. **Always validate input** sebelum send ke firebase
2. **Use TextEditingController.dispose()** untuk cleanup
3. **Check mounted** setelah async operation
4. **Set loading state** saat proses firebase berjalan
5. **Handle exceptions** dengan specific error messages
6. **Store user data di Firestore** walaupun sudah di Firebase Auth
7. **Use role-based navigation** untuk redirect ke screen yang benar

