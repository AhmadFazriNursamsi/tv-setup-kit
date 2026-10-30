# Catatan & jebakan dari Xiaomi MiTV-MOSR4 (30 Oktober 2026)

TV: Xiaomi TV A 32 (2026), MiTV-MOSR4 / irobot, MediaTek, Google TV 11 (SDK 30), firmware
`RTM5.220609.003.1585`, RAM 1 GB. Hasil: 33 paket nonaktif, launcher CleanYourTV, tema keluarga,
Liliya v1.0.16. Siaran antena DVB-T2, HDMI, YouTube, Netflix, Miracast dan pemutar flashdisk tetap jalan.

## Yang tidak boleh dimatikan di model ini

| Paket | Alasan |
|---|---|
| `com.mitv.livetv` | Live TV **dan** menu Input/HDMI ada di aplikasi ini |
| `mitv.service`, `com.mitv.overseaservice` | Layanan TV inti, tombol remote, tombol Netflix |
| `com.mediatek.*` (tvinput, tv.service, network) | Tuner, HDMI, jaringan |
| `com.mi.bluetooth` | Remote Bluetooth |
| `com.xiaomi.mitv.smartshare`, `com.xiaomi.wfdsinkhelperservice` | Miracast (dipakai keluarga) |
| `com.mitv.videoplayer`, `com.mitv.gallery` | Putar video/foto dari flashdisk (dipakai keluarga) |
| `com.xiaomi.mitv.updateservice` | Updater firmware: dibiarkan aktif untuk patch keamanan |

## Jebakan yang benar-benar terjadi

1. **Restart paksa launcher membuat Android crash.** `tools/theme.ps1` CleanYourTV me-restart Home
   (force-stop). Dengan helper tombol aksesibilitas aktif, system_server crash
   (`Service not registered: AccessibilityServiceConnection`), TV soft-reboot, jaringan putus, layar
   hitam. Solusi di `tv-setup.ps1 -Step theme`: tulis file lewat ThemeProvider tanpa force-stop, lalu
   ubah `font_scale` sebentar agar Home dibangun ulang tanpa mematikan prosesnya.
2. **Remote mati setelah soft-reboot.** Bukan rusak: sambungan Bluetooth nyangkut. Tahan
   **Home + Menu (☰)** di dekat TV untuk memasangkan ulang.
3. **Config baru tidak terbaca setelah reboot.** Saat boot launcher menyala sebelum penyimpanan siap
   dan memakai salinan config lama. Ubah `font_scale` sekali setelah boot (sudah dilakukan skrip).
4. **Wallpaper baru tidak berganti tanpa reboot.** Gambar disimpan di memori proses launcher.
5. **Setup wizard harus dimatikan sebelum launcher Google TV.** Kalau terbalik, Home jatuh ke
   `setupwraith/.RecoveryActivity`; reboot dalam keadaan itu pernah membuat TV lain ter-factory-reset.
   Periksa dulu `dumpsys wifi | grep cname=`: di unit ini Wi-Fi milik `android.uid.system` (aman).
6. **Tombol Input/YouTube/Netflix/Settings mati** begitu launcher Google TV dimatikan (firmware 1585).
   Solusi: helper `-InputKeyService -HomeKeyService` + `app_keys` di config. Harganya: menahan
   tombol volume naik hanya 1 langkah per tekan.
7. **Google Assistant (katniss) dimatikan** = mic remote dan perintah suara Liliya di TV ikut mati.
8. **Load average ~60 itu normal** di TV ini: puluhan thread driver MediaTek berstatus D. Lihat %idle.
9. **Gradle pertama kali** bisa gagal karena unduhan terputus. Jalankan ulang saja.
10. **Git Bash mengubah path TV** (`/data/local/tmp/...` jadi `C:/Program Files/Git/...`): jalankan
    alat dari PowerShell, atau set `MSYS_NO_PATHCONV=1`.

## Mengembalikan semuanya

- Per batch: `<cleanyourtv>\tools\restore.ps1 models\xiaomi-mitv-mosr4\batches\<batch>.txt`
- Launcher Google TV: `restore.ps1 <daftar> com.google.android.apps.tv.launcherx`
- Tanpa laptop: Settings > Apps > Show system apps > pilih aplikasi > Enable
- Record restore otomatis: `%USERPROFILE%\.cleanyourtv\recovery-<ip>-*.json`
