// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Fungsi Login dan Pengambilan Role
  Future<Map<String, dynamic>> signIn({required String email, required String password}) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;

      // Ambil data user dari koleksi 'users' untuk mendapatkan role
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(uid).get();
      
      String role = userDoc['role'] as String; 
      
      return {'success': true, 'role': role}; // Sukses, kembalikan role

    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Login gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }

  // Fungsi Register (khusus Customer)
  Future<Map<String, dynamic>> registerCustomer({required String email, required String password, required String name}) async {
    try {
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      String uid = userCredential.user!.uid;
      
      // Simpan role di Firestore
      await _firestore.collection('users').doc(uid).set({
        'name': name,
        'email': email,
        'role': 'customer', 
        'created_at': FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Registrasi berhasil!'};
      
    } on FirebaseAuthException catch (e) {
      return {'success': false, 'message': e.message ?? 'Registrasi gagal'};
    } catch (e) {
      return {'success': false, 'message': 'Terjadi kesalahan: $e'};
    }
  }
}