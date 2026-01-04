# Konsep Dasar dan Lifecycle Flutter (Panduan Pemula)

Flutter adalah "alat tukang" yang kita pakai untuk membangun rumah (aplikasi) ini. Dokumen ini menjelaskan aturan main Flutter yang dipakai di Geges Smart Barber.

---

## 1. Widget: Semuanya adalah Balok Lego

Di Flutter, tombol, teks, gambar, bahkan jarak antar elemen (Padding) adalah **Widget**. Kita menyusun widget-widget ini menjadi halaman.

*   **StatelessWidget:** Widget patung. Sekali dibuat, dia diam saja. Contoh: Teks judul, Ikon.
*   **StatefulWidget:** Widget robot. Dia bisa berubah-ubah kalau ada data baru. Contoh: Layar Antrean (bisa nambah/kurang), Form input.

---

## 2. Siklus Hidup Widget (Lifecycle)

Bayangkan halaman aplikasi punya nyawa. Kita harus urus kelahirannya dan kematiannya agar memori HP tidak bocor (aplikasi jadi berat).

**Contoh Nyata:** `lib/screens/customer/home_screen.dart`

### A. Lahir (`initState`)
Dipanggil **sekali saja** saat halaman pertama kali dibuka.
```dart
@override
void initState() {
  super.initState();
  // Mulai ambil data barbershop saat halaman lahir
  _barbershopFuture = _barbershopService.getAllBarbershops();
  // Mulai cari lokasi GPS
  _updateLocation();
}
```

### B. Hidup (`build`)
Dipanggil berkali-kali setiap ada perubahan (misal: keyboard muncul, layar diputar, `setState` dipanggil). Di sini kita menyusun tampilan UI.

### C. Mati (`dispose`)
Dipanggil saat halaman ditutup/pindah ke halaman lain. **Wajib** bersih-bersih di sini!
```dart
@override
void dispose() {
  // Matikan controller biar memori RAM lega
  _pageController.dispose();
  _searchController.dispose();
  _debounce?.cancel(); // Stop timer pencarian
  super.dispose();
}
```
*Kalau lupa `dispose`, aplikasi lama-lama akan lemot karena sampah memori menumpuk.*

---

## 3. Optimalisasi Performa (Biar Tidak Lag)

### A. ListView.builder (Malas itu Bagus)
Kalau kita punya 1000 data barbershop, jangan digambar semua sekaligus! HP bisa panas.
Kita pakai `ListView.builder`. Dia hanya menggambar apa yang **terlihat di layar**. Kalau user scroll ke bawah, baru dia gambar yang di bawah.

### B. Const Constructor
Kita sering pakai kata kunci `const` di depan widget (misal: `const SizedBox(height: 10)`).
*   **Artinya:** "Widget ini tidak akan berubah selamanya".
*   **Efeknya:** Flutter tidak perlu menggambar ulang widget ini setiap detik. Hemat baterai dan CPU.

### C. Image Caching
Gambar dimuat dari internet pakai `CachedNetworkImage`.
*   **Gunanya:** Gambar disimpan di memori HP setelah pertama kali download. Jadi kalau buka halaman itu lagi, tidak perlu pakai kuota internet lagi. Hemat kuota user!
