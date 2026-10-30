# Menambah TV baru yang belum ada di `models/`

1. Jalankan `.\tv-setup.ps1 -TvHost <ip> -Step probe` lalu `-Step backup` dan `-Step plan`.
   `plan` mencari model TV di daftar CleanYourTV (`examples/`) dan menyebut folder yang cocok.
2. Buat `models/<merek-model>/` dengan isi seperti `models/xiaomi-mitv-mosr4/`:
   - `model.json`: `product_model` (sama persis dengan `getprop ro.product.model`), `stock_launcher`,
     `live_tv_package`, `disable_before_launcher`, `never_disable`, dan helper tombol bila perlu.
   - `batches/N-nama.txt`: satu paket per baris. Baris pertama adalah judul. Awali judul dengan
     `OPSIONAL` untuk batch pilihan keluarga (default tidak), atau `LAUNCHER` untuk paket yang baru
     boleh dimatikan saat memasang launcher.
   - `theme/config.json` (dan `wallpaper.jpg` bila mau).
3. Isi batch dari `examples/<folder>/debloat.txt` CleanYourTV, tapi **buang** semua paket Live TV,
   tuner, TV input, HDMI, remote/Bluetooth, keyboard, Play Store/Services. Ragu soal satu paket?
   Cek `dumpsys package <nama>` dulu (jangan pernah membuka paket factory/fac/test).
4. Urutkan dari yang paling aman: telemetri → iklan/promo → layanan latar → aplikasi bawaan →
   pilihan keluarga. 3-7 paket per batch.
5. Jalankan `-Step debloat` dan uji siaran antena, HDMI, YouTube, dan remote setelah **setiap** batch.
6. Launcher: periksa di `docs/devices/` CleanYourTV apakah model itu butuh helper tombol, dan
   apakah setup wizard harus dimatikan dulu.

## Bukan Android TV?

Samsung (Tizen), LG (webOS), Roku, VIDAA: alat ini tidak berlaku, dan Liliya juga tidak bisa dipasang.
Matikan pelacakan lewat menu TV: https://cleanyour.tv/not-android
