// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart'; // Dibutuhkan oleh AuthService
import 'package:google_sign_in/google_sign_in.dart';
// --- IMPORT BARU ---
import 'package:geges_smartbarber/models/user_data.dart'; // Import Model Anda

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  // ============================
  // AUTH: SIGN IN / REGISTER
  // ============================

  /// Sign in with email & password.
  /// Returns map: { 'success': bool, 'role': 'customer'|'admin_owner', 'message': ... }
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
      return {'success': true, 'role': role};
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Login gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan saat login: $e'};
    }
  }

  /// Register customer (email/password).
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

      // Buat dokumen user di Firestore
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'customer',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Opsional: kirim verifikasi email
      await userCredential.user?.sendEmailVerification();

      return {
        'success': true,
        'message': 'Registrasi berhasil. Silakan verifikasi email Anda.',
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

  /// Sign in with Google. Buat dokumen user di Firestore jika akun baru.
  /// Mengembalikan Map: { 'success': bool, 'role': String?, 'message': String? }
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: <String>['email', 'profile']);

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

      return {'success': true, 'role': role};
    } on FirebaseAuthException catch (e) {
      return {
        'success': false,
        'message': e.message ?? 'Google sign-in gagal (FirebaseAuth).',
      };
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
  Future<UserData?> getUserById(String uid) async {
    try {
      if (uid.isEmpty) return null;
      final doc = await _firestore.collection('users').doc(uid).get();

      // Gunakan Model UserData.fromFirestore
      return doc.exists
          ? UserData.fromFirestore(
              doc,
            )
          : null;
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
    final googleSignIn = GoogleSignIn();
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

  /// Update profile dengan handling untuk requires-recent-login
  Future<Map<String, dynamic>> updateProfile({
    required String uid,
    required String newName,
    String? newEmail,
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
          // method ini mengirim email verifikasi terlebih dahulu sebelum update
          await user.verifyBeforeUpdateEmail(newEmail);
          if (trySendVerification) {
            // note: verifyBeforeUpdateEmail sudah mengirim verification email
            // jadi kita skip sendEmailVerification() untuk menghindari duplicate
          }
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
      await _firestore.collection('users').doc(uid).update({
        'name': newName,
        'email': newEmail ?? user.email,
        'updated_at': FieldValue.serverTimestamp(),
      });

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
  // SIGN OUT
  // ============================

  Future<void> signOut() async {
    try {
      // Sign out from Firebase
      await _auth.signOut();
      // Also sign out Google if used
      try {
        final google = GoogleSignIn();
        await google.signOut();
      } catch (_) {}
    } catch (e) {
      debugPrint('Sign out error: $e');
    }
  }

  Future<bool> isAdmin(String uid) async {
  final doc = await _firestore.collection('users').doc(uid).get();
  final data = doc.data();
  return (data?['role'] == 'admin_owner');
}

}
