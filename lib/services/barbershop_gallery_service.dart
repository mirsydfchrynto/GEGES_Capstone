import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class BarbershopGalleryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // -----------------------
  // 📸 UPLOAD PHOTO
  // -----------------------

  /// Upload foto baru ke barbershop gallery
  /// Returns URL foto yang berhasil di-upload
  Future<String?> uploadPhoto(
    String barbershopId,
    File imageFile, {
    String? caption,
  }) async {
    try {
      final fileName =
          'barbershop_$barbershopId/photo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final ref = _storage.ref().child(fileName);

      // Upload file
      final uploadTask = await ref.putFile(imageFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      // Add URL to barbershop's photoUrls array
      await _firestore.collection('barbershops').doc(barbershopId).update({
        'photoUrls': FieldValue.arrayUnion([downloadUrl]),
      });

      // Optionally store metadata (caption, timestamp, etc) in subcollection
      if (caption != null && caption.isNotEmpty) {
        await _firestore
            .collection('barbershops')
            .doc(barbershopId)
            .collection('gallery_metadata')
            .add({
              'url': downloadUrl,
              'caption': caption,
              'uploadedAt': FieldValue.serverTimestamp(),
            });
      }

      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading photo: $e');
      rethrow;
    }
  }

  // -----------------------
  // 🖼️ GET GALLERY URLS
  // -----------------------

  /// Get all photo URLs untuk barbershop tertentu
  Future<List<String>> getPhotoUrls(String barbershopId) async {
    try {
      final doc = await _firestore.collection('barbershops').doc(barbershopId).get();
      if (!doc.exists) return [];

      final photoUrls = (doc.data()?['photoUrls'] as List<dynamic>?)
          ?.whereType<String>()
          .toList() ?? [];

      return photoUrls;
    } catch (e) {
      debugPrint('Error getting photo URLs: $e');
      return [];
    }
  }

  /// Stream photo URLs real-time
  Stream<List<String>> streamPhotoUrls(String barbershopId) {
    return _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists) return [];
          final photoUrls = (snapshot.data()?['photoUrls'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ?? [];
          return photoUrls;
        });
  }

  // -----------------------
  // 🗑️ DELETE PHOTO
  // -----------------------

  /// Delete foto dari barbershop gallery
  Future<void> deletePhoto(String barbershopId, String photoUrl) async {
    try {
      // Remove from array
      await _firestore.collection('barbershops').doc(barbershopId).update({
        'photoUrls': FieldValue.arrayRemove([photoUrl]),
      });

      // Delete from storage (extract path from URL)
      try {
        final ref = _storage.refFromURL(photoUrl);
        await ref.delete();
      } catch (e) {
        debugPrint('Warning: could not delete storage file: $e');
        // Non-blocking error - firestore array already removed
      }

      // Remove metadata
      try {
        final metadataQuery = await _firestore
            .collection('barbershops')
            .doc(barbershopId)
            .collection('gallery_metadata')
            .where('url', isEqualTo: photoUrl)
            .get();

        for (final doc in metadataQuery.docs) {
          await doc.reference.delete();
        }
      } catch (e) {
        debugPrint('Warning: could not delete metadata: $e');
      }
    } catch (e) {
      debugPrint('Error deleting photo: $e');
      rethrow;
    }
  }

  // -----------------------
  // 📝 UPDATE PHOTO CAPTION
  // -----------------------

  /// Update caption untuk foto tertentu
  Future<void> updatePhotoCaption(
    String barbershopId,
    String photoUrl,
    String newCaption,
  ) async {
    try {
      final metadataQuery = await _firestore
          .collection('barbershops')
          .doc(barbershopId)
          .collection('gallery_metadata')
          .where('url', isEqualTo: photoUrl)
          .get();

      if (metadataQuery.docs.isEmpty) {
        // Create new metadata if doesn't exist
        await _firestore
            .collection('barbershops')
            .doc(barbershopId)
            .collection('gallery_metadata')
            .add({
              'url': photoUrl,
              'caption': newCaption,
              'uploadedAt': FieldValue.serverTimestamp(),
            });
      } else {
        // Update existing
        for (final doc in metadataQuery.docs) {
          await doc.reference.update({'caption': newCaption});
        }
      }
    } catch (e) {
      debugPrint('Error updating photo caption: $e');
      rethrow;
    }
  }

  // -----------------------
  // 📊 GET GALLERY METADATA
  // -----------------------

  /// Get metadata untuk semua foto (captions, upload dates, etc)
  Stream<List<Map<String, dynamic>>> streamGalleryMetadata(String barbershopId) {
    return _firestore
        .collection('barbershops')
        .doc(barbershopId)
        .collection('gallery_metadata')
        .orderBy('uploadedAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => {
                    'url': doc['url'],
                    'caption': doc['caption'] as String?,
                    'uploadedAt': doc['uploadedAt'] as Timestamp?,
                    ...doc.data(),
                  })
              .toList();
        });
  }
}
