#!/bin/bash

echo "🚀 Memulai Deployment Firestore Security Rules (Super Admin Mode)..."

# Cek apakah firebase CLI terinstall
if ! command -v firebase &> /dev/null
then
    echo "❌ Error: Firebase CLI tidak ditemukan."
    echo "   Silakan install dengan: npm install -g firebase-tools"
    echo "   Lalu login dengan: firebase login"
    exit 1
fi

# Deploy hanya firestore rules
echo "📦 Mengirim aturan keamanan ke Firestore..."
firebase deploy --only firestore:rules

if [ $? -eq 0 ]; then
    echo "✅ SUKSES! Website Super Admin sekarang memiliki akses total ke Firestore."
else
    echo "❌ GAGAL. Pastikan Anda sudah login (firebase login) dan berada di direktori project yang benar."
fi