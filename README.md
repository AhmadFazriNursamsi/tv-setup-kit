# TV Setup Kit

Menyiapkan Android TV / Google TV di rumah: buang bloatware, iklan, dan telemetri, pasang launcher
ringan, wallpaper keluarga, dan aplikasi **Liliya**. Semuanya bisa dikembalikan. Kit ini membungkus
alat [CleanYourTV](https://github.com/Gathin23/cleanyourtv) dan pengamannya, ditambah daftar paket,
urutan langkah, dan jebakan yang sudah teruji di TV kita.

**Sudah teruji:** Xiaomi TV A 32 (2026), MiTV-MOSR4, firmware 1585 → [`models/xiaomi-mitv-mosr4`](models/xiaomi-mitv-mosr4)

## Yang dibutuhkan

- Laptop Windows di Wi-Fi yang sama dengan TV: Python 3, Git, JDK 17, Android SDK 34 (untuk build launcher)
- Di TV: Settings > System > About > tekan OK 7x pada **Build** > Developer options > **USB debugging** ON
- IP TV (Settings > Network)

## Pakai

```powershell
cd C:\Users\atep\tv-setup-kit
.\tv-setup.ps1 -TvHost 192.168.1.6          # alur lengkap, bertanya di setiap langkah
```

Alur lengkap: probe → backup → cocokkan model → debloat per batch (uji antena/HDMI setiap batch) →
launcher → tema/wallpaper → Liliya → pengingat menutup ADB.

Satu langkah saja:

| Perintah | Fungsi |
|---|---|
| `-Step setup` | Unduh CleanYourTV + venv Python (sekali saja) |
| `-Step probe` | Sambung ke TV, tampilkan model/Android/firmware |
| `-Step backup` | Simpan daftar paket, getprop, dan settings ke `backups/` |
| `-Step plan` | Tunjukkan batch untuk model ini dan paket yang ada di TV |
| `-Step debloat [-Batch 1]` | Nonaktifkan per batch (atau satu batch tanpa pertanyaan) |
| `-Step launcher` | Matikan setup wizard dulu, lalu build + pasang launcher dengan helper tombol |
| `-Step theme [-Theme <folder>]` | Kirim config + wallpaper tanpa restart paksa launcher |
| `-Step liliya` | Unduh & pasang APK Liliya terbaru dari GitHub Releases |
| `-Step check-closed` | Pastikan port ADB 5555 sudah tertutup |

## Wallpaper keluarga

```powershell
python -I tools\make-wallpaper.py foto1.jpg foto2.jpg -o models\xiaomi-mitv-mosr4\theme\wallpaper.jpg
.\tv-setup.ps1 -TvHost 192.168.1.6 -Step theme
```

Foto disusun utuh berdampingan (tidak dipotong atau diperbesar), dan data EXIF/GPS dibuang.
`*.jpg` tidak ikut git (lihat `.gitignore`), jadi foto keluarga tetap di laptop.

## Setelah selesai: tutup ADB

Developer options → **Cabut otorisasi USB debugging** → matikan **USB debugging** → matikan
**Developer options** → mulai ulang TV → `.\tv-setup.ps1 -TvHost <ip> -Step check-closed`.

## Dokumen

- [docs/CATATAN.md](docs/CATATAN.md): paket yang tidak boleh dimatikan, jebakan yang pernah terjadi, cara restore
- [docs/TV-BARU.md](docs/TV-BARU.md): menambah model TV baru

## Bukan plug and play penuh

Liliya bisa dipasang di Android TV mana pun (Android 8+). Daftar debloat **khusus per model dan
firmware**: TV baru perlu folder `models/` sendiri (lihat TV-BARU.md). Samsung/LG tidak didukung.
