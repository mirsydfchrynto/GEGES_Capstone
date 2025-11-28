## Option B: Dry-Run Cleanup Script - Step-by-Step Guide

### 📋 Overview
Script ini mengidentifikasi booking duplikat di Firestore **tanpa membuat perubahan apapun** (dry-run mode). Setelah review hasil, Anda bisa memutuskan apakah perlu full cleanup atau tidak.

### 🎯 Tujuan
- Identifikasi duplikat yang ada di database existing
- Tentukan mana booking yang "authoritative" (harus dikeep)
- Report apa yang akan dihapus jika full cleanup dijalankan

### 📊 Duplikat Detection Logic
Duplikat diidentifikasi berdasarkan kombinasi:
- **User ID** (siapa yang booking)
- **Scheduled At** (waktu booking)
- **Service ID** (layanan apa)

Jika kombinasi ini sama, berarti duplikat → satu dikeep (authoritative), sisanya marked.

### 🔍 Authoritative Selection Priority
Jika ada 3+ booking duplikat, pilih authoritative dengan prioritas:

1. **Priority 1: Sudah ada bukti pembayaran**
   - Jika `payment.proofUrl` != null, itu authoritative
   - Alasan: booking ini sudah progress jauh, jangan dihapus

2. **Priority 2: Sudah verified pembayaran**
   - Jika `payment.verificationStatus` == 'accepted', itu authoritative
   - Alasan: admin sudah approve, jangan dihapus

3. **Priority 3: Terbaru (latest createdAt)**
   - Booking dengan `createdAt` paling baru
   - Alasan: kemungkinan lebih valid, data terbaru

### 🚀 Cara Menjalankan

#### Step 1: Import Test Function (Optional - untuk manual testing)
Jika ingin test manual, import di file testing atau temp:

```dart
import 'package:geges_smartbarber/test_dry_run_migration.dart';

// Kemudian panggil:
await testDryRunMigration();
```

#### Step 2: Jalankan Dry-Run via Admin Panel (RECOMMENDED)
Tambahkan button ke admin dashboard untuk run dry-run kapan saja:

```dart
// Di admin_dashboard.dart atau migration screen baru
ElevatedButton(
  onPressed: () async {
    final migration = DuplicateBookingMigration();
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Running dry-run analysis...'))
    );
    
    try {
      await migration.dryRun();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Dry-run complete. Check console for report.'),
          backgroundColor: Colors.green,
        )
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  },
  child: const Text('🔍 Run Dry-Run Analysis'),
),
```

#### Step 3: Review Console Output
Dry-run akan print ke console:

```
🔍 === DRY RUN MODE (No changes made) ===

🔍 Mulai identifikasi duplikat...
📊 Hasil: 3 grup duplikat ditemukan
  - doc1, doc2, doc3 (3 docs)
  - doc4, doc5 (2 docs)
  - doc6, doc7, doc8, doc9 (4 docs)

🎯 Tentukan booking authoritative...

📋 REPORT - What would be done:
Total duplikat groups: 3

  Group: doc1, doc2, doc3
    - KEEP (authoritative): doc1
    - REMOVE (mark as duplicate_removed): doc2, doc3

  Group: doc4, doc5
    - KEEP (authoritative): doc4
    - REMOVE (mark as duplicate_removed): doc5

  Group: doc6, doc7, doc8, doc9
    - KEEP (authoritative): doc7
    - REMOVE (mark as duplicate_removed): doc6, doc8, doc9

📊 Summary:
  - Total booking groups with duplicates: 3
  - Total duplicate documents to mark: 7
  - Total authoritative to keep: 3

✅ Dry run completed. To apply changes, call runFullCleanup()
```

### 📋 Interpreting Report

**KEEP (authoritative)**: Booking ini akan dipertahankan karena:
- Memiliki bukti pembayaran, atau
- Sudah diverifikasi admin, atau
- Paling baru dibuat

**REMOVE (mark as duplicate_removed)**: Booking ini akan di-soft-delete dengan:
- Status: `'duplicate_removed'`
- Added field: `reason: 'Booking duplikat, authoritative adalah [doc_id]'`
- Added field: `removedAt: serverTimestamp()`

### ⚠️ Important Notes

1. **Dry-run TIDAK MENGUBAH DATA** - Sepenuhnya safe untuk dijalankan berulang kali
2. **Review dulu sebelum full cleanup** - Pastikan report terlihat masuk akal
3. **Soft delete, bukan hard delete** - Data tidak dihapus, hanya di-mark status
4. **Dapat di-recover** - Jika ada kesalahan, bisa update status kembali

### ✅ Next Steps (Setelah Dry-Run OK)

Jika report terlihat baik, jalankan full cleanup:

```dart
final migration = DuplicateBookingMigration();
await migration.runFullCleanup();
```

Full cleanup akan:
- Mark semua duplicate dengan status: `'duplicate_removed'`
- Update UI queries agar ignore `'duplicate_removed'` bookings
- Disimpan di Firestore untuk audit trail

### 🧪 Testing di Staging

1. Deploy dengan appointment_screen fix (✅ sudah done)
2. Create beberapa test bookings → satu selesai dengan payment, satu cancel, etc
3. Jalankan dry-run → lihat apakah terdeteksi duplikat
4. Review report
5. Jika OK, proceed ke full cleanup
6. Verify UI tidak menampilkan marked duplicates

---

**File locations:**
- Test function: `lib/test_dry_run_migration.dart`
- Original script: `MIGRATION_CLEANUP_SCRIPT.dart`
- Service impl: `lib/services/booking_anti_duplicate_service.dart` (identifyDuplicateBookings method)
