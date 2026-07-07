# Anichin Beta

Aplikasi nonton donghua/anime, data diambil dari API:
`https://api.nexray.eu.cc/anime/anichin`

- App name: **Anichin Beta**
- Package/Application ID: `com.dev.anichinbeta`

## Kenapa gak ada folder `android/` di dalam zip?

Sengaja. Folder native Android (gradle, AGP, dll) itu isinya versi-versi yang
harus PAS cocok satu sama lain DAN cocok dengan versi Flutter SDK yang dipakai
buat build. Kalau ditulis manual, gampang banget salah versi dan build gagal
(ini yang sempat kejadian sebelumnya).

Jadi solusinya: folder `android/` di-generate OTOMATIS oleh Flutter SDK itu
sendiri, baik di lokal maupun pas build di Codemagic — dijamin selalu cocok
sama versi Flutter yang lagi kepakai saat itu.

## Cara Setup di Lokal

1. Pastikan Flutter SDK sudah terinstall (`flutter --version`).
2. Masuk ke folder project, jalankan:
   ```
   flutter create --platforms=android --org com.dev .
   ```
   Ini akan generate folder `android/` dengan applicationId `com.dev.anichinbeta`
   secara otomatis (org `com.dev` + nama project `anichinbeta` di pubspec.yaml),
   TANPA menimpa kode di folder `lib/`.
3. (Opsional, biar nama aplikasi "Anichin Beta" bukan "Anichinbeta") edit
   `android/app/src/main/AndroidManifest.xml`, ganti atribut `android:label`
   jadi `"Anichin Beta"`.
4. Install dependency:
   ```
   flutter pub get
   ```
5. Jalankan di emulator/device:
   ```
   flutter run
   ```

## Build via Codemagic

Project ini sudah dilengkapi `codemagic.yaml` di root folder, workflow-nya:

1. `flutter create --platforms=android --org com.dev .` — generate folder
   android otomatis pakai versi Gradle/AGP yang cocok dengan Flutter SDK
   di mesin Codemagic saat itu.
2. Patch `android:label` di AndroidManifest.xml jadi "Anichin Beta".
3. `flutter pub get`
4. `flutter build apk --release`

Yang perlu kamu lakukan:
1. Push project ini ke repo Git (GitHub/GitLab/Bitbucket).
2. Di Codemagic, tambahkan aplikasi baru dari repo tersebut.
3. Codemagic otomatis pakai `codemagic.yaml` yang sudah ada, workflow `android-workflow`.
4. Notifikasi build (sukses/gagal) dikirim ke: `zyrooquestion@gmail.com`
5. Hasil APK ada di artifact `build/**/outputs/**/*.apk`.

## Struktur Project

```
lib/
  main.dart
  models/home_model.dart       -> parsing JSON dari endpoint /home
  services/api_service.dart    -> fetch data dari API
  widgets/anime_card_widget.dart
  screens/home_screen.dart     -> featured slider, popular today, latest releases
pubspec.yaml                   -> nama project: anichinbeta
codemagic.yaml
```
(folder `android/` sengaja tidak disertakan — lihat penjelasan di atas)

## Catatan

- Featured slider di home screen dibuat manual pakai `PageView` bawaan Flutter
  (bukan package `carousel_slider`), karena package tersebut masih bentrok
  nama class `CarouselController` dengan widget bawaan Flutter versi baru
  dan belum ada fix resminya di pub.dev.
- UI sudah di-redesign gaya iOS: large title header yang collapse pas scroll
  (`CupertinoSliverNavigationBar`), pull-to-refresh gaya iOS, dan design token
  warna/tipografi terpusat di `lib/theme/app_theme.dart`.
- Halaman detail anime & video player belum dibuat, baru home screen.
- Signing APK masih pakai debug key bawaan Flutter (belum pakai keystore
  sendiri). Untuk rilis ke Play Store, perlu bikin keystore sendiri dan
  ditambahkan signing config di `android/app/build.gradle.kts` setelah
  folder android digenerate.
- Folder `ios/` juga belum disertakan dengan alasan yang sama. Kalau nanti
  mau build iOS juga, jalankan `flutter create --platforms=ios .` di lokal.
