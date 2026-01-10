// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // untuk defaultTargetPlatform
import 'package:google_sign_in/google_sign_in.dart';
import 'package:geges_smartbarber/models/user_data.dart';
import 'package:geges_smartbarber/services/session_service.dart';


// Public interface so tests can inject a fake implementation without initializing Firebase
abstract class AuthServiceBase {
  User? get currentUser;
  Future<void> signOut();
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  });
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  });
  Future<Map<String, dynamic>> signInWithGoogle();
  Future<Map<String, dynamic>> sendPasswordResetEmail({required String email});
  Future<UserData?> getUserById(String uid);
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  });
}

class AuthService implements AuthServiceBase {
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuth get auth => _auth;

  // Constructor defined below (includes optional GoogleSignIn injection)
  @override
  User? get currentUser => _auth.currentUser;

  // ============================ 
  // AUTH: SIGN IN / REGISTER
  // ============================ 

  /// Sign in with email & password.
  /// Returns map: { 'success': bool, 'role': 'customer'|'admin_owner', 'message': ... }
  @override
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // Ambil data pengguna di Firestore
      final doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists || doc.data() == null) {
        return {'success': false, 'message': 'Data pengguna tidak ditemukan.'};
      }

      final data = doc.data() as Map<String, dynamic>;
      final role = (data['role'] as String?) ?? 'customer';
      
      // LOG SUCCESS: Tampilkan di konsol saat berhasil login
      debugPrint('AUTH SUCCESS: User logged in!');
      debugPrint('   - UID: $uid');
      debugPrint('   - Role: $role');

      // Log teknis untuk validasi token JWT
      debugPrint("DEBUG AUTHENTICATION");
      debugPrint("User UID: $uid");
      try {
        final current = _auth.currentUser;
        if (current != null) {
          final token = await current.getIdToken();
          debugPrint("Firebase ID Token (JWT):");
          debugPrint(token);
          
          // Persist session info (uid & token)
          await SessionService().saveSession(uid: uid, idToken: token);
        }
      } catch (e) {
        debugPrint("Error retrieving token: $e");
      }
      debugPrint("END DEBUG AUTHENTICATION");

      // Record login audit (non-blocking)
      try {
        await _recordLoginAudit(uid);
      } catch (e) {
        debugPrint('Login audit failed: $e');
      }

      return {'success': true, 'role': role};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthErrorMessage(e)};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan saat login: $e'};
    }
  }

  String _mapAuthErrorMessage(FirebaseAuthException e) {
    final msg = (e.message ?? '').toLowerCase();
    // Map common FirebaseAuth error codes/messages to friendly Indonesian strings
    if (msg.contains('recaptcha') ||
        msg.contains('reCAPTCHA'.toLowerCase()) ||
        msg.contains('captcha')) {
      return 'Verifikasi reCAPTCHA gagal atau token kosong. Periksa konfigurasi Firebase Auth reCAPTCHA dan koneksi jaringan. Untuk debugging, coba sign-in dengan email/password.';
    }

    switch (e.code) {
      case 'user-not-found':
        return 'Email tidak ditemukan.';
      case 'wrong-password':
        return 'Password salah.';
      case 'invalid-email':
        return 'Format email salah.';
      case 'invalid-credential':
        return 'Credential tidak valid atau kadaluwarsa. Coba lagi atau periksa konfigurasi Google Sign-In (SHA-1).';
      case 'too-many-requests':
        return 'Terlalu banyak percobaan login. Coba lagi nanti.';
      case 'network-request-failed':
        return 'Gagal koneksi jaringan. Periksa koneksi Anda.';
      default:
        return e.message ?? 'Login gagal.';
    }
  }

  /// Register customer (email/password).
  @override
  Future<Map<String, dynamic>> registerCustomer({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      // Update display name pada Firebase Auth
      await userCredential.user?.updateDisplayName(name);

      // LOG SUCCESS: Tampilkan di konsol saat registrasi berhasil
      debugPrint('REGISTER SUCCESS: New customer created!');
      debugPrint('   - Name: $name');
      debugPrint('   - Email: $email');
      debugPrint('   - UID: $uid');

      // Buat dokumen user di Firestore
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Save session after register to improve UX
      try {
        final current = _auth.currentUser;
        if (current != null) {
          final token = await current.getIdToken();
          await SessionService().saveSession(uid: uid, idToken: token);
        }
      } catch (_) {}

      return {
        'success': true,
        'message': 'Registrasi berhasil. Selamat datang!',
      };
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Registrasi gagal'};
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat registrasi: $e',
      };
    }
  }

  // ============================ 
  // GOOGLE SIGN IN
  // ============================ 
  final GoogleSignIn? _googleSignIn;

  AuthService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    GoogleSignIn? googleSignIn,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _googleSignIn = googleSignIn;

  @override
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final googleSignIn = _googleSignIn ??
          GoogleSignIn(
            serverClientId: '51527807075-2jpi3mhgcg8nrcu9snhh1fjhbn747u4r.apps.googleusercontent.com',
            scopes: <String>['email', 'profile'],
          );

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return {
          'success': false,
          'message': 'Google sign-in dibatalkan oleh pengguna.',
        };
      }

      final googleAuth = await googleUser.authentication;

      // Jika idToken atau accessToken null -> gagal autentikasi
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        return {
          'success': false,
          'message': 'Gagal mendapatkan token dari Google.',
        };
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user!;
      final uid = user.uid;

      // Jika user baru, buat dokumen user
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (!userDoc.exists || userDoc.data() == null) {
        await _firestore.collection('users').doc(uid).set({
          'name': user.displayName ?? 'User',
          'email': user.email ?? '',
          'role': 'customer',
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      // Ambil role dari dokumen Firestore (aman)
      final doc = await _firestore.collection('users').doc(uid).get();
      final raw = doc.data();
      if (raw is! Map<String, dynamic>) {
        return {
          'success': false,
          'message': 'Format data user tidak valid di Firestore.',
        };
      }
      final role = (raw['role'] as String?) ?? 'customer';

      try {
        final current = _auth.currentUser;
        if (current != null) {
          final token = await current.getIdToken();
          await SessionService().saveSession(uid: uid, idToken: token);
        }
      } catch (_) {}

      return {'success': true, 'role': role};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': _mapAuthErrorMessage(e)};
    } on Exception catch (e) {
      // Tangani khusus ApiException: 10 (common Android Google Sign-in error)
      final msg = e.toString();
      if (msg.contains('ApiException: 10') ||
          msg.contains('sign_in_failed') ||
          msg.contains('DEVELOPER_ERROR')) {
        return {
          'success': false,
          'message':
              'Terjadi kesalahan saat Google sign-in: (ApiException: 10). Ini biasanya disebabkan oleh konfigurasi OAuth/SHA-1 yang belum cocok.\n\n'
              'Solusi: tambahkan SHA-1 (debug/release) di Firebase Console, download ulang google-services.json, lalu rebuild app.\n\n'
              'Jika sudah di Play Store gunakan SHA Play App Signing juga.',
        };
      }
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat Google sign-in: $e',
      };
    }
  }

  // ============================ 
  // PASSWORD RESET
  // ============================ 

  /// Kirim link reset password
  @override
  Future<Map<String, dynamic>> sendPasswordResetEmail({
    required String email,
  }) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return {
        'success': true,
        'message': 'Link reset password telah dikirim ke $email.',
      };
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Gagal mengirim reset password.',
      };
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // ============================ 
  // GET USER DATA (FIRESTORE)
  // ============================ 

  // --- PERBAIKAN DI SINI ---
  // Mengganti 'getUserByIdRaw' (Map) menjadi 'getUserById' (Model)
  // Ini akan digunakan oleh AdminDashboard untuk menampilkan nama customer
  @override
  Future<UserData?> getUserById(String uid) async {
    try {
      if (uid.isEmpty) return null;
      final doc = await _firestore.collection('users').doc(uid).get();

      // Gunakan Model UserData.fromFirestore
      return doc.exists ? UserData.fromFirestore(doc) : null;
    } catch (e) {
      debugPrint('Error getUserById: $e');
      return null;
    }
  }
  // --- AKHIR PERBAIKAN ---

  // ============================ 
  // UPDATE PROFILE & REAUTH
  // ============================ 

  /// Reauthenticate using current password (email/password accounts)
  Future<void> reauthWithPassword(String email, String currentPassword) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  /// Reauthenticate using GoogleSignIn (for Google provider)
  Future<void> reauthWithGoogle() async {
    final googleSignIn = GoogleSignIn(
      serverClientId: '51527807075-2jpi3mhgcg8nrcu9snhh1fjhbn747u4r.apps.googleusercontent.com',
    );
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Google sign-in aborted',
      );
    }
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    await _auth.currentUser!.reauthenticateWithCredential(credential);
  }

  // Helper: Record login audit and update user.last_login
  Future<void> _recordLoginAudit(String uid) async {
    // Best-effort: write a concise audit document and update the user's last_login
    final platform = defaultTargetPlatform.toString();

    try {
      await _firestore.collection('login_audit').add({
        'uid': uid,
        'event': 'login',
        'platform': platform,
        'created_at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // non-fatal: log and continue to attempt updating last_login
      debugPrint('Login audit add failed (continuing): $e');
    }

    // update last_login on user document
    try {
      await _firestore.collection('users').doc(uid).update({
        'last_login': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      // non-fatal if update fails (e.g., permission rules); log and continue
      debugPrint('Failed to update last_login for $uid: $e');
    }
  }

  /// Update profile dengan handling untuk requires-recent-login
  Future<Map<String, dynamic>> updateProfile({
    required String uid,
    required String newName,
    String? newEmail,
    String? newPhoneNumber,
    String? newPhotoBase64,
    String? currentPasswordForReauth, // optional: jika ada, pakai untuk reauth
    bool trySendVerification = true,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != uid) {
      return {
        'success': false,
        'code': 'no-auth',
        'message': 'Pengguna tidak terautentikasi.',
      };
    }

    try {
      // 1) Update displayName di Firebase Auth (jika berubah)
      if (user.displayName != newName) {
        await user.updateDisplayName(newName);
      }

      // 2) Update email di Firebase Auth (jika berbeda dan tak null)
      if (newEmail != null && newEmail.isNotEmpty && user.email != newEmail) {
        try {
          // gunakan verifyBeforeUpdateEmail untuk yang lebih aman
          await user.verifyBeforeUpdateEmail(newEmail);
        } on FirebaseAuthException catch (e) {
          // Jika perlu reauth, kembalikan kode khusus supaya UI memanggil reauth flow
          if (e.code == 'requires-recent-login') {
            return {
              'success': false,
              'code': 'requires-recent-login',
              'message':
                  'Aksi sensitif, perlu login ulang. Mohon masukkan password atau re-login dengan provider Anda.',
            };
          }
          return {
            'success': false,
            'code': e.code,
            'message': e.message ?? 'Gagal memperbarui email.',
          };
        }
      }

      // 3) Update Firestore document
      final Map<String, dynamic> updates = {
        'name': newName,
        'email': newEmail ?? user.email,
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      if (newPhoneNumber != null) {
        updates['phone_number'] = newPhoneNumber;
      }
      
      if (newPhotoBase64 != null) {
        updates['photo_base_64'] = newPhotoBase64;
      }

      await _firestore.collection('users').doc(uid).update(updates);

      return {'success': true, 'message': 'Profile berhasil diperbarui.'};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'code': e.code,
        'message': e.message ?? 'Gagal memperbarui profile.',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Terjadi kesalahan saat update profile: $e',
      };
    }
  }

  /// Utility: try reauth then retry update (dipanggil dari UI)
  Future<Map<String, dynamic>> reauthAndUpdateProfile({
    required String uid,
    required String newName,
    String? newEmail,
    String? currentPassword,
  }) async {
    try {
      if (currentUser == null) {
        return {'success': false, 'message': 'User tidak ada.'};
      }

      // note: fetchSignInMethodsForEmail deprecated untuk security reason
      // sebagai alternatif, kami just proceed dengan operasi & handle requires-recent-login error di catch
      // ini lebih aman sesuai Firebase best practices

      // if requires recent login, akan throw error dan user diminta re-auth
      return await updateProfile(
        uid: uid,
        newName: newName,
        newEmail: newEmail,
        trySendVerification: true,
      );
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Re-auth gagal',
        'code': e.code,
      };
    } catch (e) {
      return {'success': false, 'message': 'Re-auth gagal: $e'};
    }
  }

  // ============================ 
  // CHANGE PASSWORD
  // ============================ 

  /// Mengubah password dengan verifikasi password lama terlebih dahulu
  @override
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) {
      throw 'User tidak ditemukan';
    }

    try {
      // 1. Buat kredensial dari email & password lama
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      // 2. Re-autentikasi (Verifikasi Password Lama)
      await user.reauthenticateWithCredential(credential);

      // 3. Jika berhasil verifikasi, update ke password baru
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        throw 'Password lama yang Anda masukkan salah.';
      } else if (e.code == 'weak-password') {
        throw 'Password baru terlalu lemah.';
      } else if (e.code == 'requires-recent-login') {
        throw 'Sesi habis. Silakan login ulang untuk mengganti password.';
      }
      throw e.message ?? 'Gagal mengubah password.';
    } catch (e) {
      throw 'Terjadi kesalahan sistem: $e';
    }
  }

  // ============================ 
  // SIGN OUT
  // ============================ 

  @override
  Future<void> signOut() async {
    final currentUid = _auth.currentUser?.uid;
    try {
      // Sign out from Firebase
      await _auth.signOut();
      // Also sign out Google if used
      try {
        final google = GoogleSignIn(
          serverClientId: '51527807075-2jpi3mhgcg8nrcu9snhh1fjhbn747u4r.apps.googleusercontent.com',
        );
        await google.signOut();
      } catch (_) {}
    } catch (e) {
      debugPrint('Sign out error: $e');
    } finally {
      // Record logout audit (best-effort)
      try {
        if (currentUid != null) {
          await _firestore.collection('login_audit').add({
            'uid': currentUid,
            'event': 'logout',
            'platform': defaultTargetPlatform.toString(),
            'created_at': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        debugPrint('Logout audit failed: $e');
      }

      // Clear persisted session data
      await SessionService().clearSession();
    }
  }

  Future<bool> isAdmin(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data();
    return (data?['role'] == 'admin_owner');
  }
}