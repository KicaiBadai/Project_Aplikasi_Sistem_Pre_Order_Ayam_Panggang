# 🍗 Aplikasi Sistem Pre-Order Ayam Panggang

Aplikasi berbasis **Flutter** untuk melakukan pemesanan (pre-order) Ayam Panggang secara online. Aplikasi ini memiliki sistem notifikasi real-time yang terintegrasi dengan **OneSignal** serta backend yang dikelola menggunakan **Supabase** (Autentikasi & Database).

---

## ✨ Fitur Utama

- **Pemesanan Pre-Order**: Memudahkan pelanggan memesan ayam panggang secara online.
- **Multi-Role User**:
  - **Admin**: Mengelola pesanan, melihat laporan penjualan, mengonfirmasi pembayaran, serta mengubah status pesanan.
  - **Customer**: Melakukan pemesanan, mengunggah bukti pembayaran, serta memantau status pesanan mereka.
- **Notifikasi Real-Time (OneSignal)**: Notifikasi otomatis ketika ada pesanan baru untuk Admin, serta pembaruan status pesanan untuk Customer.
- **Ekspor Dokumen**: Cetak invoice langsung ke format **PDF**.
- **Peta Lokasi**: Integrasi dengan layanan geospasial untuk deteksi alamat.

---

## 🛠️ Teknologi yang Digunakan

- **Frontend**: [Flutter SDK](https://flutter.dev/) (Dart)
- **State Management**: [Riverpod](https://riverpod.dev/)
- **Backend / Database**: [Supabase](https://supabase.com/)
- **Push Notification**: [OneSignal](https://onesignal.com/)
- **Environment Utility**: `flutter_dotenv`

---

## 🚀 Panduan Instalasi

Ikuti langkah-langkah di bawah ini untuk menjalankan project ini di komputer lokal Anda:

### 1. Prasyarat (Prerequisites)
Pastikan Anda sudah menginstal beberapa software berikut:
- **Flutter SDK** (Versi terbaru atau minimal v3.19.0)
- **Dart SDK**
- **Git**
- Perangkat Emulator Android/iOS atau Device Fisik yang terhubung.

---

### 2. Kloning Repositori
Jalankan perintah berikut di terminal Anda untuk mengklon project ini:
```bash
git clone https://github.com/KicaiBadai/Project_Aplikasi_Sistem_Pre_Order_Ayam_Panggang.git
cd sistem_pre_order_ayam
```

---

### 3. Konfigurasi Environment (`.env`)
Aplikasi ini menggunakan file `.env` untuk menyimpan kunci API sensitif. 

Buat file bernama `.env` di root direktori project (sejajar dengan `pubspec.yaml`), lalu isi dengan konfigurasi berikut:

```env
SUPABASE_URL=https://<PROJECT-ID>.supabase.co
SUPABASE_ANON_KEY=<YOUR-SUPABASE-ANON-KEY>
ONESIGNAL_APP_ID=<YOUR-ONESIGNAL-APP-ID>
ONESIGNAL_REST_API_KEY=<YOUR-ONESIGNAL-REST-API-KEY>
```

> [!IMPORTANT]
> Pastikan file `.env` telah didaftarkan pada bagian `assets` di file `pubspec.yaml` agar terbaca oleh Flutter (Sudah terkonfigurasi secara default di dalam project).

---

### 4. Instal Dependensi
Jalankan perintah berikut untuk mengunduh semua package dan library yang dibutuhkan aplikasi:
```bash
flutter pub get
```

---

### 5. Pengaturan Platform (Opsional / OneSignal)
#### Android
Aplikasi OneSignal membutuhkan izin notifikasi pada perangkat Android 13 ke atas. Pengaturan ini telah disematkan pada file `AndroidManifest.xml`.
#### iOS
Buka folder `ios` dan jalankan `pod install` jika Anda menggunakan perangkat macOS untuk dideploy ke iOS simulator/device:
```bash
cd ios
pod install
cd ..
```

---

### 6. Menjalankan Aplikasi
Jalankan perintah berikut untuk mengompilasi dan menjalankan aplikasi:
```bash
flutter run
```

---
