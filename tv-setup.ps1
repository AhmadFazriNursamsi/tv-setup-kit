# tv-setup.ps1 - siapkan Android TV / Google TV baru: probe, backup, debloat per batch, launcher,
# tema/wallpaper, dan aplikasi Liliya. Memakai alat CleanYourTV (github.com/Gathin23/cleanyourtv)
# beserta semua pengaman bawaannya; skrip ini hanya menambah urutan dan pelajaran dari TV Xiaomi
# MOSR4 (lihat docs/CATATAN.md).
#
# Pemakaian (PowerShell, dari folder repo ini):
#   .\tv-setup.ps1 -TvHost 192.168.1.6                 # alur lengkap, bertanya di setiap langkah
#   .\tv-setup.ps1 -TvHost 192.168.1.6 -Step probe     # satu langkah saja
#   .\tv-setup.ps1 -TvHost 192.168.1.6 -Step debloat -Batch 1   # satu batch tanpa pertanyaan
# Langkah: setup, probe, backup, plan, debloat, launcher, theme, liliya, check-closed, all
#
# Aturan yang tidak boleh dilanggar: hanya pm disable-user (tidak pernah uninstall), batch kecil
# dengan uji siaran antena/HDMI setelah tiap batch, dan setup wizard dimatikan SEBELUM launcher bawaan.
param(
    [ValidateSet('setup', 'probe', 'backup', 'plan', 'debloat', 'launcher', 'theme', 'liliya', 'check-closed', 'all')]
    [string]$Step = 'all',
    [string]$TvHost = $env:TV_HOST,
    [string]$CleanYourTV = (Join-Path $env:USERPROFILE 'cleanyourtv'),
    [string]$Model = '',
    [string]$Theme = '',
    [string]$Batch = ''
)
$ErrorActionPreference = 'Stop'
$OutputEncoding = New-Object System.Text.UTF8Encoding $false
$Kit = $PSScriptRoot
$Py = Join-Path $CleanYourTV 'tools\venv\Scripts\python.exe'
$LiliyaRepo = 'AhmadFazriNursamsi/liliya-home'

function Say($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "!! $msg" -ForegroundColor Yellow }

function Ask($question, [bool]$default = $false) {
    $hint = if ($default) { '[Y/n]' } else { '[y/N]' }
    $a = Read-Host "$question $hint"
    if (-not $a) { return $default }
    return $a -match '^[yY]'
}

# ---------------- CleanYourTV & koneksi ----------------

function Ensure-CleanYourTV {
    if (-not (Test-Path (Join-Path $CleanYourTV 'tools\tv.py'))) {
        Say "Mengunduh CleanYourTV ke $CleanYourTV"
        git clone https://github.com/Gathin23/cleanyourtv $CleanYourTV
        if ($LASTEXITCODE -ne 0) { throw 'git clone CleanYourTV gagal' }
    }
    if (-not (Test-Path $Py)) {
        Say 'Membuat venv Python untuk alat ADB'
        python -m venv (Join-Path $CleanYourTV 'tools\venv')
        & $Py -m pip install -q -r (Join-Path $CleanYourTV 'tools\requirements.txt')
        if ($LASTEXITCODE -ne 0) { throw 'pip install gagal' }
    }
}

function Need-Host {
    if (-not $TvHost) { throw 'Isi -TvHost <IP TV> (Settings > Network di TV) atau set $env:TV_HOST' }
    $env:TV_HOST = $TvHost
}

function Tv([string]$cmd) {
    $out = & $Py -I (Join-Path $CleanYourTV 'tools\tv.py') $cmd
    if ($LASTEXITCODE -ne 0) { throw "perintah TV gagal: $cmd" }
    return $out
}

function Tv-Tool([string]$script, [string[]]$toolArgs) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $CleanYourTV "tools\$script") @toolArgs
    if ($LASTEXITCODE -ne 0) { throw "$script gagal (exit $LASTEXITCODE)" }
}

function Get-TvInfo {
    $props = @{}
    $vals = @(Tv 'getprop ro.product.model; getprop ro.product.device; getprop ro.build.version.sdk; getprop ro.build.display.id')
    $props.model = "$($vals[0])".Trim(); $props.device = "$($vals[1])".Trim()
    $props.sdk = [int]"$($vals[2])".Trim(); $props.build = "$($vals[3])".Trim()
    return $props
}

function Installed-Packages {
    return @(Tv 'pm list packages' | ForEach-Object { "$_".Trim() -replace '^package:', '' } | Where-Object { $_ })
}

function Disabled-Packages {
    return @(Tv 'pm list packages -d' | ForEach-Object { "$_".Trim() -replace '^package:', '' } | Where-Object { $_ })
}

# ---------------- Model ----------------

function Find-Model($info) {
    if ($Model) {
        $dir = if (Test-Path $Model) { $Model } else { Join-Path $Kit "models\$Model" }
        return Get-Item $dir
    }
    foreach ($m in Get-ChildItem (Join-Path $Kit 'models') -Directory) {
        $json = Get-Content (Join-Path $m.FullName 'model.json') -Raw | ConvertFrom-Json
        if ($json.product_model -eq $info.model) { return $m }
    }
    return $null
}

function Read-ModelJson($dir) { Get-Content (Join-Path $dir 'model.json') -Raw | ConvertFrom-Json }

function Batch-Files($dir) { @(Get-ChildItem (Join-Path $dir 'batches') -Filter '*.txt' | Sort-Object Name) }

function Batch-Packages($file) {
    @(Get-Content $file | ForEach-Object { ($_ -replace '#.*$', '').Trim() } | Where-Object { $_ })
}

function Batch-Title($file) { ((Get-Content $file -TotalCount 1) -replace '^#\s*', '') }

# ---------------- Langkah ----------------

function Step-Probe {
    Say 'Probe TV (terima "Allow USB debugging?" di TV bila muncul)'
    & $Py -I (Join-Path $CleanYourTV 'tools\tv.py') --probe
    if ($LASTEXITCODE -ne 0) { throw 'TV tidak terjangkau: cek IP, USB debugging, dan jaringan yang sama' }
    $info = Get-TvInfo
    if ($info.sdk -lt 26) { Warn "SDK $($info.sdk) < 26: launcher tidak bisa dipasang, hanya debloat." }
    return $info
}

function Step-Backup($info) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'
    $dir = Join-Path $Kit "backups\$($info.model)-$stamp"
    New-Item -ItemType Directory -Force $dir | Out-Null
    Say "Backup ke $dir"
    $items = [ordered]@{
        'packages.txt' = 'pm list packages'; 'packages-disabled.txt' = 'pm list packages -d'
        'packages-3rdparty.txt' = 'pm list packages -3'; 'getprop.txt' = 'getprop'
        'settings-global.txt' = 'settings list global'; 'settings-secure.txt' = 'settings list secure'
        'settings-system.txt' = 'settings list system'
    }
    foreach ($k in $items.Keys) { Tv $items[$k] | Set-Content -Encoding utf8 (Join-Path $dir $k) }
    Write-Host "  $((Get-ChildItem $dir).Count) file tersimpan (folder backups/ tidak ikut git)"
}

function Step-Plan($info) {
    $m = Find-Model $info
    if (-not $m) {
        Warn "Belum ada folder models/ untuk $($info.model) ($($info.device), build $($info.build))."
        $hits = @(Select-String -Path (Join-Path $CleanYourTV 'examples\*\*') -Pattern ([regex]::Escape($info.model)), ([regex]::Escape($info.device)) -List -ErrorAction SilentlyContinue |
            ForEach-Object { Split-Path (Split-Path $_.Path -Parent) -Leaf } | Sort-Object -Unique)
        if ($hits.Count) {
            Write-Host "  Daftar CleanYourTV yang menyebut model ini: $($hits -join ', ')"
            Write-Host "  Salin examples\<folder>\debloat.txt ke models\<nama>\batches\ dibagi per batch, buang paket"
            Write-Host "  Live TV/tuner/HDMI, lalu tulis model.json (contoh: models\xiaomi-mitv-mosr4)."
        } else {
            Write-Host '  Tidak ada daftar yang cocok: ikuti PROMPT.md di CleanYourTV untuk menyusun daftar baru.'
        }
        Write-Host '  Lihat juga docs\TV-BARU.md.'
        return $null
    }
    $mj = Read-ModelJson $m.FullName
    Say "Model cocok: $($mj.name)"
    if ($mj.tested_builds -notcontains $info.build) {
        Warn "Firmware TV ($($info.build)) beda dari yang diuji ($($mj.tested_builds -join ', ')): jalani batch lebih pelan."
    }
    $installed = Installed-Packages
    $disabled = Disabled-Packages
    foreach ($f in Batch-Files $m.FullName) {
        $pk = Batch-Packages $f.FullName
        $here = @($pk | Where-Object { $installed -contains $_ })
        $done = @($here | Where-Object { $disabled -contains $_ })
        $bad = @($pk | Where-Object { $mj.never_disable -contains $_ })
        Write-Host ("  {0,-22} {1,2} paket, {2,2} ada di TV, {3,2} sudah off  - {4}" -f $f.BaseName, $pk.Count, $here.Count, $done.Count, (Batch-Title $f.FullName))
        if ($bad.Count) { Warn "    berisi paket yang tidak boleh dimatikan: $($bad -join ', ')" }
    }
    return $m
}

function Run-Batch($mdir, $mj, $file, $installed) {
    $pk = Batch-Packages $file.FullName
    $bad = @($pk | Where-Object { $mj.never_disable -contains $_ })
    if ($bad.Count) { throw "$($file.Name) berisi paket wajib ($($bad -join ', ')); perbaiki daftarnya dulu" }
    $here = @($pk | Where-Object { $installed -contains $_ })
    if (-not $here.Count) { Write-Host "  $($file.BaseName): tidak ada paketnya di TV ini, dilewati"; return }
    $tmp = Join-Path $env:TEMP "tvkit-$($file.BaseName).txt"
    @("# $(Batch-Title $file.FullName)") + $here | Set-Content -Encoding ascii $tmp
    # disable.ps1 CleanYourTV: menolak paket inti Android, menjaga Home & Wi-Fi setupwraith, dan menulis
    # record restore di ~/.cleanyourtv
    Tv-Tool 'disable.ps1' @($tmp)
    $core = Tv 'pidof mitv.service com.mitv.overseaservice com.mi.bluetooth system_server'
    Write-Host "  Layanan inti masih jalan (pid): $core"
}

function Step-Debloat($info) {
    $m = Find-Model $info
    if (-not $m) { throw "Tidak ada models/ untuk $($info.model); jalankan -Step plan dulu" }
    $mj = Read-ModelJson $m.FullName
    $installed = Installed-Packages
    $files = Batch-Files $m.FullName | Where-Object { (Batch-Title $_.FullName) -notmatch '^LAUNCHER' }
    if ($Batch) {
        $f = $files | Where-Object { $_.BaseName -like "$Batch*" } | Select-Object -First 1
        if (-not $f) { throw "Batch '$Batch' tidak ada (pilihan: $(($files | ForEach-Object BaseName) -join ', '))" }
        Run-Batch $m.FullName $mj $f $installed
        return
    }
    foreach ($f in $files) {
        $title = Batch-Title $f.FullName
        $optional = $title -match '^OPSIONAL'
        Write-Host "`n  $($f.BaseName): $title"
        Write-Host "  Paket: $((Batch-Packages $f.FullName) -join ', ')"
        if (-not (Ask '  Nonaktifkan batch ini?' (-not $optional))) { continue }
        Run-Batch $m.FullName $mj $f $installed
        Write-Host '  Uji di TV sekarang: siaran antena, tombol Input/HDMI, YouTube, remote.' -ForegroundColor Green
        if (-not (Ask '  Semua masih normal? Lanjut ke batch berikutnya?' $true)) {
            Warn "Berhenti. Kembalikan batch ini dengan: $CleanYourTV\tools\restore.ps1 $($f.FullName)"
            return
        }
    }
    Write-Host '  Menunggu 15 detik agar Android menulis status paket sebelum reboot berikutnya...'
    Tv 'sync; sleep 15; echo ok' | Out-Null
}

function Step-Launcher($info) {
    if ($info.sdk -lt 26) { throw "SDK $($info.sdk): launcher butuh Android 8 (SDK 26) atau lebih baru" }
    $m = Find-Model $info
    if (-not $m) { throw "Tidak ada models/ untuk $($info.model)" }
    $mj = Read-ModelJson $m.FullName
    # Urutan aman (docs/CATATAN.md): setup wizard off dulu selagi launcher bawaan masih aktif
    $disabled = Disabled-Packages
    $prep = @($mj.disable_before_launcher | Where-Object { $disabled -notcontains $_ })
    if ($prep.Count) {
        Say "Menonaktifkan dulu: $($prep -join ', ') (disable.ps1 memeriksa pemilik Wi-Fi)"
        $tmp = Join-Path $env:TEMP 'tvkit-prelauncher.txt'
        @('# sebelum launcher') + $prep | Set-Content -Encoding ascii $tmp
        Tv-Tool 'disable.ps1' @($tmp)
    }
    $apk = Join-Path $CleanYourTV 'launcher\app\build\outputs\apk\release\app-release.apk'
    if (-not (Test-Path $apk)) {
        Say 'Build launcher (pertama kali mengunduh Gradle, bisa beberapa menit)'
        if (-not $env:JAVA_HOME) {
            $jdk = Get-ChildItem 'C:\Program Files\Java' -Directory -Filter 'jdk-17*' -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($jdk) { $env:JAVA_HOME = $jdk.FullName }
        }
        if (-not $env:ANDROID_HOME) { $env:ANDROID_HOME = Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
        Push-Location (Join-Path $CleanYourTV 'launcher')
        try {
            if (-not (Test-Path local.properties)) { "sdk.dir=$($env:ANDROID_HOME -replace '\\', '\\')" | Out-File -Encoding ascii local.properties }
            .\gradlew.bat assembleRelease -q --console=plain
            if ($LASTEXITCODE -ne 0) { throw 'build launcher gagal (unduhan Gradle terputus? jalankan lagi)' }
        } finally { Pop-Location }
    }
    Say 'Memasang launcher dan menjadikannya Home'
    $installArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', (Join-Path $CleanYourTV 'launcher\build-and-install.ps1'), '-StockLauncher', $mj.stock_launcher)
    if ($mj.input_key_service) { $installArgs += '-InputKeyService' }
    if ($mj.home_key_service) { $installArgs += '-HomeKeyService' }
    $env:SKIP_BUILD = '1'
    & powershell @installArgs
    $code = $LASTEXITCODE
    Remove-Item env:SKIP_BUILD
    if ($code -ne 0) { throw 'build-and-install.ps1 gagal; skripnya sudah rollback Home bila perlu' }
    Write-Host '  Tekan Home, Input, YouTube, Netflix, Settings di REMOTE ASLI untuk menguji.' -ForegroundColor Green
    Warn 'Jangan jalankan tools\theme.ps1 CleanYourTV di TV ini: restart paksa launcher membuat system_server crash. Pakai -Step theme.'
}

# Tulis file tema lewat ThemeProvider milik launcher (sama seperti theme.ps1) TANPA force-stop.
function Put-ThemeFile($local, $name) {
    $dir = '/sdcard/Android/data/com.gathin.tvhome/files'
    $uri = 'content://com.gathin.tvhome.theme'
    $tmp = "/data/local/tmp/tvkit-$name"
    & $Py -I (Join-Path $CleanYourTV 'tools\b64push.py') $local $tmp | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw "kirim $name gagal" }
    Tv "rm -f $dir/$name 2>/dev/null; { o=`$(content write --uri $uri/$name < $tmp 2>&1) && case `"`$o`" in *'Unsupported operation'*|*'Error while accessing provider'*) false ;; esac; } || { cp $tmp $dir/$name 2>/dev/null; }; rm -f $tmp" | Out-Null
}

function Reload-Launcher {
    # Mengubah ukuran font sebentar membuat Home dibangun ulang (membaca config baru) tanpa mematikan
    # prosesnya, jadi helper tombol remote tetap terikat.
    Tv 'settings put system font_scale 1.05; sleep 4; settings put system font_scale 1.0; sleep 4; input keyevent HOME' | Out-Null
}

function Step-Theme($info) {
    $dir = $Theme
    if (-not $dir) {
        $m = Find-Model $info
        if ($m) { $dir = Join-Path $m.FullName 'theme' }
    }
    if (-not $dir -or -not (Test-Path (Join-Path $dir 'config.json'))) { throw 'Folder tema (dengan config.json) tidak ditemukan; pakai -Theme <folder>' }
    Get-Content (Join-Path $dir 'config.json') -Raw | ConvertFrom-Json | Out-Null
    Say "Mengirim tema dari $dir"
    Put-ThemeFile (Join-Path $dir 'config.json') 'config.json'
    $wall = Join-Path $dir 'wallpaper.jpg'
    $hasWall = Test-Path $wall
    if ($hasWall) { Put-ThemeFile $wall 'wallpaper.jpg' }
    # Revisi baru memberi tahu launcher bahwa pilihan lama di TV (urutan dock dll.) tidak berlaku lagi
    $revFile = Join-Path $env:TEMP 'tvkit-theme_revision'
    [IO.File]::WriteAllText($revFile, [guid]::NewGuid().ToString('N'))
    Put-ThemeFile $revFile 'theme_revision'
    if ($hasWall) {
        Write-Host '  Wallpaper baru baru tampil setelah reboot.'
        if (Ask '  Reboot TV sekarang?' $true) {
            Tv 'sync; sleep 3; echo ok' | Out-Null
            & $Py -I (Join-Path $CleanYourTV 'tools\tv.py') --reboot | Out-Null
            Write-Host '  Menunggu TV menyala lagi...'
            Start-Sleep 25
            for ($i = 0; $i -lt 40; $i++) {
                $ok = $false
                try { $ok = (Tv 'getprop sys.boot_completed') -match '1' } catch { }
                if ($ok) { break }
                Start-Sleep 5
            }
            Start-Sleep 12
        }
    }
    Reload-Launcher
    Write-Host '  Tema diterapkan.'
}

function Step-Liliya {
    Say 'Memasang Liliya versi terbaru dari GitHub Releases'
    $rel = Invoke-RestMethod -UseBasicParsing "https://api.github.com/repos/$LiliyaRepo/releases?per_page=10"
    $asset = $rel | ForEach-Object { $_.assets } | Where-Object { $_.name -like 'Liliya-*.apk' } | Select-Object -First 1
    if (-not $asset) { throw 'APK Liliya tidak ditemukan di releases' }
    $apk = Join-Path $env:TEMP $asset.name
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $apk
    Write-Host "  $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
    & $Py -I (Join-Path $CleanYourTV 'tools\b64push.py') $apk /data/local/tmp/liliya.apk | Select-Object -Last 1
    if ($LASTEXITCODE -ne 0) { throw 'kirim APK gagal' }
    Tv 'pm install -r /data/local/tmp/liliya.apk; rm -f /data/local/tmp/liliya.apk'
    Write-Host '  Buka Liliya sekali di TV untuk login. Mic butuh Google Assistant (katniss) tetap aktif.'
}

function Step-CheckClosed {
    Say 'Memeriksa port ADB 5555 (TV harus menyala & tersambung)'
    & $Py -I (Join-Path $CleanYourTV 'tools\adb-closed.py') $TvHost
}

function Close-Reminder {
    Say 'Langkah terakhir di TV'
    Write-Host '  Settings > System > Developer options:'
    Write-Host '   1. Cabut otorisasi USB debugging (Revoke USB debugging authorizations)'
    Write-Host '   2. Matikan USB debugging, lalu matikan Developer options'
    Write-Host '   3. Mulai ulang TV, lalu: .\tv-setup.ps1 -TvHost <ip> -Step check-closed'
}

# ---------------- Main ----------------

Ensure-CleanYourTV
if ($Step -eq 'setup') { Say 'CleanYourTV & venv siap'; exit 0 }
Need-Host
if ($Step -eq 'check-closed') { Step-CheckClosed; exit $LASTEXITCODE }
if ($Step -eq 'liliya') { Step-Liliya; exit 0 }

$info = Get-TvInfo
switch ($Step) {
    'probe' { Step-Probe | Out-Null }
    'backup' { Step-Backup $info }
    'plan' { Step-Plan $info | Out-Null }
    'debloat' { Step-Debloat $info }
    'launcher' { Step-Launcher $info }
    'theme' { Step-Theme $info }
    'all' {
        $info = Step-Probe
        Write-Host "TV: $($info.model) ($($info.device)), SDK $($info.sdk), build $($info.build)"
        Step-Backup $info
        $m = Step-Plan $info
        if (-not $m) { exit 0 }
        Write-Host "`nSebelum lanjut: pastikan siaran antena tampil dan catat salurannya." -ForegroundColor Green
        Step-Debloat $info
        if (Ask "`nPasang launcher CleanYourTV sekarang?" $true) { Step-Launcher $info }
        if (Ask "`nKirim tema/wallpaper?" $true) { Step-Theme $info }
        if (Ask "`nPasang aplikasi Liliya?" $true) { Step-Liliya }
        Close-Reminder
    }
}
