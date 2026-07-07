# Anichin Beta

Aplikasi nonton donghua/anime, data diambil dari API:
`https://api.nexray.eu.cc/anime/anichin`

- App name: **Anichin Beta**
- Package/Application ID: `com.dev.anichinbeta`

## Cara Setup di Lokal

1. Pastikan Flutter SDK sudah terinstall (`flutter --version`).
2. Masuk ke folder project, jalankan:
   ```
   flutter create --platforms=android .
   ```
   Perintah ini WAJIB dijalankan sekali di awal. Fungsinya untuk melengkapi
   file-file native Android yang tidak bisa dibuat manual (gradlew binary,
   local.properties, dll), tanpa menimpa kode di folder `lib/` atau
   `AndroidManifest.xml` / `build.gradle` yang sudah dikustomisasi.
3. Install dependency:
   ```
   flutter pub get
   ```
4. Jalankan di emulator/device:
   ```
   flutter run
   ```

## Build via Codemagic

Project ini sudah dilengkapi `codemagic.yaml` di root folder.

1. Push project ini ke repo Git (GitHub/GitLab/Bitbucket).
2. Di Codemagic, tambahkan aplikasi baru dari repo tersebut.
3. Codemagic otomatis akan pakai `codemagic.yaml`, workflow `android-workflow`.
   Step pertama di workflow sebaiknya kamu tambahkan juga:
   ```
   flutter create --platforms=android .
   ```
   sebelum `flutter pub get`, supaya file gradle wrapper otomatis lengkap
   di environment build Codemagic (mesin Codemagic sudah include Flutter SDK,
   jadi command ini aman & cepat).
4. Notifikasi build (sukses/gagal) akan dikirim ke: `zyrooquestion@gmail.com`
5. Hasil APK ada di artifact `build/**/outputs/**/*.apk`.

## Struktur Project

```
lib/
  main.dart
  models/home_model.dart       -> parsing JSON dari endpoint /home
  services/api_service.dart    -> fetch data dari API
  widgets/anime_card_widget.dart
  screens/home_screen.dart     -> featured slider, popular today, latest releases
android/                       -> project native Android (applicationId com.dev.anichinbeta)
pubspec.yaml
codemagic.yaml
```

## Catatan

- Folder `ios/` belum disertakan. Kalau nanti mau build iOS juga, jalankan
  `flutter create --platforms=ios .` di lokal buat generate project Xcode-nya.
- Signing APK masih pakai debug key (`signingConfigs.debug`) supaya bisa
  langsung build tanpa setup keystore dulu. Untuk rilis ke Play Store,
  perlu bikin keystore sendiri dan diganti di `android/app/build.gradle`.
- Halaman detail anime & video player belum dibuat, baru home screen.
- Config Android pakai format **Kotlin DSL** (`build.gradle.kts` / `settings.gradle.kts`),
  bukan Groovy (`.gradle`), menyesuaikan template Flutter terbaru. Jangan sampai ada
  dobel file `build.gradle` dan `build.gradle.kts` di folder yang sama — itu bikin build gagal.
- Gradle wrapper pakai versi 8.10.2 (minimum yang dibutuhkan Flutter versi baru adalah 8.7).
