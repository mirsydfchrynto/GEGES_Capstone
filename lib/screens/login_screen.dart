// ==========================================
// file: lib/screens/login_screen.dart
// deskripsi: layar login untuk masuk ke aplikasi
// penjelasan:
//   - user memasukkan email & password
//   - ada tombol login biasa & google sign-in
//   - ada tombol forgot password untuk reset password
//   - setelah login berhasil, navigasi ke home (customer) atau admin dashboard
// ==========================================

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:geges_smartbarber/l10n/generated/app_localizations.dart';
import 'package:geges_smartbarber/services/auth_service.dart';
import 'package:geges_smartbarber/screens/customer/home_screen.dart';
import 'package:geges_smartbarber/screens/admin/admin_dashboard.dart';
import 'package:geges_smartbarber/screens/register_screen.dart';

// penjelasan statefulwidget:
// - loginscreen adalah statefulwidget karena ada state yang berubah (error message, loading, password visible)
// - setstate() dipanggil untuk update ui saat ada perubahan
class LoginScreen extends StatefulWidget {
  final AuthServiceBase? authService;
  final WidgetBuilder? homeBuilder;
  final WidgetBuilder? adminBuilder;
  const LoginScreen({
    super.key,
    this.authService,
    this.homeBuilder,
    this.adminBuilder,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // penjelasan controller:
  // - textEditingController digunakan untuk menangkap text yang user ketik di TextField
  // - _emailController untuk menangkap input email
  // - _passwordController untuk menangkap input password
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Focus nodes for inputs (used to animate focused state)
  late final FocusNode _emailFocusNode;
  late final FocusNode _passwordFocusNode;

  // penjelasan authservice:
  // - authservice adalah service yang menangani semua operasi autentikasi (login, register, google sign-in)
  // - sudah diimplementasikan di lib/services/auth_service.dart
  AuthServiceBase? _authService;

  // penjelasan variabel state:
  // - _errorMessage: menampilkan pesan error jika login gagal (email tidak terdaftar, password salah, dll)
  // - _isLoading: flag untuk menampilkan loading spinner saat proses login sedang berjalan
  // - _obscurePassword: flag untuk menyembunyikan/menampilkan password (tombol mata)
  String _errorMessage = '';
  bool _isLoading = false;
  bool _obscurePassword =
      true; // made mutable to allow toggling password visibility

  // penjelasan warna tema:
  // - kBrownAccent: warna coklat utama dari design system
  // - kDarkGrey: warna background untuk input field
  // - kHintText: warna teks hint/placeholder
  static const Color kBrownAccent = Color(0xFFC3A47B);
  static const Color kDarkGrey = Color(0xFF1E1E1E);
  static const Color kHintText = Color(0xFF6B6B6B);

  @override
  void dispose() {
    // penjelasan dispose:
    // - dispose() dipanggil saat widget dihancurkan
    // - penting untuk melepaskan resources seperti controller untuk mencegah memory leak
    // - harus selalu panggil super.dispose() di akhir
    _emailController.dispose();
    _passwordController.dispose();
    // dispose focus nodes
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Defer creation to when an operation is performed; allow tests to inject a fake AuthService
    _authService = widget.authService;
    // initialize focus nodes used for animated input styling
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  // ========================================
  // fungsi login dengan email & password
  // ========================================
  void _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final l10n = AppLocalizations.of(context)!;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = l10n.errLoginEmpty);
      return;
    }

    // Simple email format validation
    final emailRegex = RegExp(r"^[\w\.-]+@[\w\.-]+\.\w+");
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = l10n.errEmailFormat);
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final auth = _authService ?? AuthService();
      final result = await auth.signIn(email: email, password: password);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (result['success'] == true) {
        _navigateByRole(result['role']);
      } else {
        setState(() => _errorMessage = result['message'] ?? l10n.errLoginFailed);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.errGeneric(e.toString());
      });
    }
  }

  // ========================================
  // navigasi berdasarkan role user
  // ========================================
  void _navigateByRole(String? role) {
    // penjelasan:
    // - role bisa 'customer' atau 'admin_owner'
    // - jika customer, navigasi ke HomeScreen
    // - jika admin_owner, navigasi ke AdminDashboardScreen
    // - pushReplacement() berarti ganti layar ini dengan layar baru (jadi tidak bisa kembali ke login)

    final l10n = AppLocalizations.of(context)!;
    Widget targetScreen;
    if (role == 'customer') {
      targetScreen = widget.homeBuilder?.call(context) ?? const HomeScreen();
    } else if (role == 'admin_owner' || role == 'owner' || role == 'admin') {
      // Accept commonly used admin role variants in DB (admin_owner, owner, admin)
      targetScreen =
          widget.adminBuilder?.call(context) ?? const AdminDashboardScreen();
    } else {
      setState(
        () => _errorMessage = l10n.errRoleInvalid(role ?? '<null>'),
      );
      return;
    }

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => targetScreen));
  }

  // ========================================
  // navigasi ke register screen
  // ========================================
  void _goToRegister() {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan tombol "sign up"
    // - navigasi ke RegisterScreen dengan transisi 0 (instant, tidak ada animasi)
    // - kosongkan error message

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation1, animation2) =>
            const RegisterScreen(),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
    if (mounted) setState(() => _errorMessage = '');
  }

  // ========================================
  // forgot password: kirim link reset ke email
  // ========================================
  void _forgotPassword() async {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan "forgot password?"
    // - jika email field kosong, tanya email melalui dialog
    // - kirim link reset password ke email melalui firebase

    final email = _emailController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    // penjelasan kondisi:
    // - jika email kosong, tanyakan via dialog
    // - jika user cancel, tampilkan snackbar
    // - jika user input email, kirim reset email
    if (email.isEmpty) {
      final typed = await _askForEmailDialog();
      if (typed == null || typed.trim().isEmpty) {
        _showSnackbar(
          l10n.dialogResetHint, // Using hint as instruction "Enter email"
          const Color(0xFFD32F2F),
        );
        return;
      }
      await _sendResetEmail(typed.trim());
      return;
    }

    await _sendResetEmail(email);
  }

  // penjelasan fungsi helper:
  // - fungsi ini mengirim reset password email ke firebase
  // - tampilkan loading spinner selama proses
  // - setelah selesai, tampilkan snackbar sukses/gagal
  Future<void> _sendResetEmail(String email) async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;
    try {
      final auth = _authService ?? AuthService();
      final res = await auth.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _showSnackbar(
          l10n.msgResetSent(email),
          kBrownAccent,
        );
      } else {
        _showSnackbar(
          res['message'] ?? l10n.msgResetFail,
          const Color(0xFFD32F2F),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnackbar(l10n.errGeneric(e.toString()), const Color(0xFFD32F2F));
    }
  }

  // ========================================
  // google sign-in
  // ========================================
  void _signInWithGoogle() async {
    // penjelasan:
    // - fungsi ini dipanggil saat user tekan tombol "continue with google"
    // - panggil _authService.signInWithGoogle() untuk authenticate dengan google
    // - jika sukses, navigasi ke home atau admin berdasarkan role
    // - jika gagal, tampilkan error message

    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final auth = _authService ?? AuthService();
      final result = await auth.signInWithGoogle();

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        _navigateByRole(result['role']);
      } else {
        final message = result['message'] ?? 'google sign-in gagal.';
        // Show a helpful snackbar and allow retry for recoverable auth errors (recaptcha/credential)
        final isRecaptcha =
            message.toLowerCase().contains('recaptcha') ||
            message.toLowerCase().contains('captcha');
        final isCredential =
            message.toLowerCase().contains('credential') ||
            message.toLowerCase().contains('oauth') ||
            message.toLowerCase().contains('developer_error');
        _showSnackbar(message, const Color(0xFFD32F2F));
        setState(() => _errorMessage = message);

        if (isRecaptcha || isCredential) {
          // Allow quick retry via snackbar action
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$message'),
              backgroundColor: const Color(0xFFD32F2F),
              action: SnackBarAction(
                label: l10n.btnRetry,
                textColor: Colors.white,
                onPressed: _signInWithGoogle,
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = l10n.errGeneric(e.toString());
      });
      // If error string contains recaptcha or credential hints, provide a retry
      final msg = e.toString().toLowerCase();
      final shouldOfferRetry =
          msg.contains('recaptcha') ||
          msg.contains('credential') ||
          msg.contains('developer_error');
      _showSnackbar(l10n.errGeneric(e.toString()), const Color(0xFFD32F2F));
      if (shouldOfferRetry) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errGeneric(e.toString())),
            backgroundColor: const Color(0xFFD32F2F),
            action: SnackBarAction(
              label: l10n.btnRetry,
              textColor: Colors.white,
              onPressed: _signInWithGoogle,
            ),
          ),
        );
      }
    }
  }

  // ========================================
  // dialog: tanya email untuk reset password
  // ========================================
  Future<String?> _askForEmailDialog() async {
    // penjelasan:
    // - dialog ini muncul saat user tekan "forgot password?" tanpa input email
    // - user bisa input email & tekan "kirim" atau tekan "batal"
    // - mengembalikan email yang diinput atau null jika dibatalkan

    final l10n = AppLocalizations.of(context)!;
    String typed = '';
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          title: Text(
            l10n.dialogResetTitle,
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(hintText: l10n.dialogResetHint),
            onChanged: (v) => typed = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: Text(l10n.dialogResetCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: kBrownAccent,
                foregroundColor: Colors.black,
              ),
              onPressed: () => Navigator.of(context).pop(typed),
              child: Text(l10n.btnSend),
            ),
          ],
        );
      },
    );
  }

  // ========================================
  // Troubleshoot dialog: helper for auth errors (recaptcha / google sign-in / SHA-1)
  // ========================================
  void _showAuthTroubleshootDialog() {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.troubleshootTitle),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text(l10n.troubleshootContent),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.btnClose),
          ),
        ],
      ),
    );
  }

  // ========================================
  // helper: tampilkan snackbar di bawah layar
  // ========================================
  void _showSnackbar(String msg, Color color) {
    // penjelasan:
    // - snackbar adalah notifikasi yang muncul di bawah layar
    // - mounted check untuk memastikan widget masih ada di memory
    // - backgroundColor color untuk warna snackbar (hijau sukses, merah error)

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 40.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo
                Image.asset(
                  'assets/images/ivon.png',
                  height: 120,
                  errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.cut, color: kBrownAccent, size: 120),
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.welcome,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 32),
                _buildAuthTabs(
                    isLogin: true,
                    onSignUpTap: _goToRegister,
                    loginLabel: l10n.signInTab,
                    signUpLabel: l10n.signUp),
                const SizedBox(height: 32),

                // Email
                _buildTextField(
                  controller: _emailController,
                  hintText: l10n.email,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  focusNode: _emailFocusNode,
                ),
                const SizedBox(height: 16),

                // Password with toggle
                _buildTextField(
                  controller: _passwordController,
                  hintText: l10n.password,
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  focusNode: _passwordFocusNode,
                  onPasswordToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                const SizedBox(height: 12),

                // Forgot Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      l10n.forgotPassword,
                      style: const TextStyle(color: kBrownAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Error Message
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Column(
                      children: [
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Color(0xFFD32F2F)),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        // Offer a Troubleshoot button for auth-specific errors
                        if (_errorMessage.toLowerCase().contains('recaptcha') ||
                            _errorMessage.toLowerCase().contains('sha') ||
                            _errorMessage.toLowerCase().contains(
                              'developer_error',
                            ))
                          TextButton(
                            onPressed: () => _showAuthTroubleshootDialog(),
                            child: const Text(
                              'Troubleshoot Sign-in',
                              style: TextStyle(color: kBrownAccent),
                            ),
                          ),
                      ],
                    ),
                  ),

                // Sign In Button
                SizedBox(
                  height: 55,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kBrownAccent),
                        )
                      : ElevatedButton(
                          onPressed: _login,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kBrownAccent,
                            foregroundColor: Colors.black,
                          ),
                          child: Text(
                            l10n.login,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 32),

                // Separator
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        l10n.orSplit,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey.shade800)),
                  ],
                ),
                const SizedBox(height: 32),

                // Google Sign-In
                SizedBox(
                  height: 55,
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: kBrownAccent),
                        )
                      : ElevatedButton.icon(
                          onPressed: _signInWithGoogle,
                          icon: Image.asset(
                            'assets/images/google.png',
                            height: 24,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(
                                  Icons.android,
                                  color: Colors.white,
                                  size: 24,
                                ),
                          ),
                          label: Text(
                            l10n.continueWithGoogle,
                            style: const TextStyle(fontSize: 16),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kDarkGrey,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.shade800),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 40),

                // Footer
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    children: [
                      TextSpan(text: l10n.termFooterPre),
                      TextSpan(
                        text: l10n.termFooterService,
                        style: const TextStyle(
                          color: kBrownAccent,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            // Open internal Terms of Service page
                            Navigator.of(context).pushNamed('/legal/terms');
                          },
                      ),
                      TextSpan(text: l10n.termFooterAnd),
                      TextSpan(
                        text: l10n.termFooterPrivacy,
                        style: const TextStyle(
                          color: kBrownAccent,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            Navigator.of(context).pushNamed('/legal/privacy');
                          },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ========================================
  // custom widget: tab untuk login/signup
  // ========================================
  Widget _buildAuthTabs({
    required bool isLogin,
    required VoidCallback onSignUpTap,
    required String loginLabel,
    required String signUpLabel,
  }) {
    // penjelasan:
    // - widget ini menampilkan 2 tab: "log in" dan "sign up"
    // - tab yang aktif memiliki background coklat
    // - tab yang tidak aktif transparan
    // - ontap callback dipanggil saat user tekan tab

    return Container(
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // penjelasan tab login:
          // - expanded membuat tab mengambil ruang sama rata
          // - container dengan background coklat untuk tab aktif
          // - text "log in" dengan alignment center
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: kBrownAccent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                loginLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          // penjelasan tab signup:
          // - gesturedetector untuk mendeteksi tap
          // - onTap callback untuk navigasi ke register screen
          // - container dengan background transparan
          Expanded(
            child: GestureDetector(
              onTap: onSignUpTap,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  signUpLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================
  // custom widget: text input field
  // ========================================
  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    FocusNode? focusNode,
    bool obscureText = false,
    VoidCallback? onPasswordToggle,
  }) {
    // penjelasan:
    // - reusable widget untuk membuat input field dengan style yang konsisten
    // - controller: menangkap text yang user ketik
    // - hinttext: placeholder text saat field kosong
    // - icon: icon di sebelah kiri input
    // - keyboardtype: tipe keyboard yang muncul (email, number, text, dll)

    final node = focusNode;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: kDarkGrey,
        borderRadius: BorderRadius.circular(20),
        boxShadow: (node != null && node.hasFocus)
            ? [
                BoxShadow(
                  color: kBrownAccent.withValues(alpha: 0.12),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: TextField(
        controller: controller,
        focusNode: node,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: kHintText),
          filled: true,
          fillColor: Colors.transparent,
          prefixIcon: Icon(icon, color: kHintText, size: 22),
          suffixIcon: onPasswordToggle != null
              ? IconButton(
                  icon: Icon(
                    obscureText ? Icons.visibility : Icons.visibility_off,
                    color: kHintText,
                  ),
                  onPressed: onPasswordToggle,
                )
              : null,
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: kBrownAccent, width: 1.5),
          ),
        ),
      ),
    );
  }
}
