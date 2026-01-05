# Buku Induk Teknis: Geges Smart Barber

Dokumen komprehensif mengenai spesifikasi teknis sistem.

## 1. Justifikasi Teknologi
Pemilihan Flutter dan Firebase didasarkan pada kebutuhan skalabilitas dan performa aplikasi cross-platform yang setara dengan native code.

## 2. Struktur Data dan Sinkronisasi
Database menggunakan model NoSQL Document-Oriented yang menawarkan fleksibilitas skema. Sinkronisasi data antar perangkat dilakukan melalui protokol komunikasi full-duplex yang menjaga integritas data secara real-time.

## 3. Protokol Keamanan
Sistem mengadopsi standar autentikasi JWT dan perlindungan integritas perangkat menggunakan Firebase App Check untuk mencegah akses dari entitas tidak terorisasi.