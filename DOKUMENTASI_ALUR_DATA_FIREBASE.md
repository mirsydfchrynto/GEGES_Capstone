# 📘 Panduan Alur Data: Dari Firebase ke Layar HP (UI)

Dokumen ini menjelaskan bagaimana data (seperti Nama Barbershop dan Gambar) berpindah dari database Firebase hingga muncul di layar aplikasi Geges Smart Barber.

---

## 1. Titik Koneksi Utama (The Gateway)
Sebelum aplikasi bisa mengambil data, ia harus "mengetuk pintu" Firebase. Di proyek ini, koneksi dilakukan di dua file utama:

*   **`lib/firebase_options.dart`**: Berisi "kunci" atau konfigurasi (API Key, Project ID) agar aplikasi tahu Firebase mana yang harus dihubungi.
*   **`lib/main.dart`**: Di sini aplikasi pertama kali dijalankan. Perhatikan baris ini:
    ```dart
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    ```
    *Tanpa baris ini, aplikasi tidak akan pernah bisa terhubung ke database.*

---

## 2. Alur 4 Langkah (Konsep Restoran)

### Langkah 1: Dapur (Firebase Firestore)
Data disimpan di awan (cloud) dalam koleksi bernama `barbershops`.
*   **Isi Data:** Nama, Alamat, dan **Gambar (format Base64)**.
*   **Kenapa Base64?** Sesuai kebijakan proyek, kita tidak menggunakan storage terpisah, jadi gambar diubah menjadi teks panjang agar bisa disimpan langsung di database.

### Langkah 2: Buku Menu (Model)
**Lokasi: `lib/models/barbershop_model.dart`**
Aplikasi butuh "cetakan" agar tidak bingung saat menerima data dari Firebase.
```dart
factory Barbershop.fromFirestore(DocumentSnapshot doc) {
  Map data = doc.data() as Map;
  return Barbershop(
    id: doc.id,
    name: data['name'],
    image: data['image'], // Ini mengambil teks panjang gambar
  );
}
```

### Langkah 3: Pelayan / API Internal (Service)
**Lokasi: `lib/services/barbershop_service.dart`**
Ini adalah bagian yang bertugas mengambil data. Jika di aplikasi lain menggunakan URL (API), di sini kita menggunakan perintah Firebase.
```dart
Stream<List<Barbershop>> getBarbershops() {
  return _db.collection('barbershops').snapshots().map(...);
}
```
*   `snapshots()` artinya aplikasi akan otomatis update jika ada perubahan data di Firebase (Real-time).

### Langkah 4: Meja Makan (UI / Widget)
**Lokasi: `lib/widgets/barbershop_card.dart`**
Di sini data ditampilkan cantik dalam bentuk kartu (Card).
*   **Menampilkan Nama:** Menggunakan widget `Text(barbershop.name)`.
*   **Menampilkan Gambar:** Karena gambarnya berupa teks Base64, kita menggunakan:
    ```dart
    Image.memory(base64Decode(barbershop.image))
    ```
    *Fungsinya: Mengubah kembali teks kode menjadi gambar asli.*

---

## 💡 Ringkasan Singkat untuk Pemula

1.  **Firebase Firestore**: Tempat simpan data (Database).
2.  **Model**: Cara aplikasi memahami struktur data (Format).
3.  **Service**: "Pipa" atau "API" yang menyedot data dari Firebase ke aplikasi.
4.  **UI (Screen/Widget)**: Tempat menampilkan data ke user (Tampilan).

---
*Dokumen ini dibuat pada: 12 Januari 2026*
