<#
.SYNOPSIS
    Provisioning RTSQ TV di Android TV / Google TV lewat ADB.

.DESCRIPTION
    Skrip ini TIDAK mengubah konten aplikasi. Ia hanya:
      1. menyambung ke perangkat (USB atau jaringan),
      2. mencatat spesifikasi perangkat,
      3. memasang APK release,
      4. menonaktifkan screensaver (opsional),
      5. menjalankan aplikasi dalam mode layar penuh,
      6. menyimpan laporan ke docs/tv-aqua-report.txt.

.PARAMETER ApkPath
    Path APK. Default: build/app/outputs/flutter-apk/app-release.apk.

.PARAMETER Serial
    Serial ADB atau alamat jaringan, mis. 192.168.1.20:5555.
    Kosong = perangkat tunggal yang sudah terhubung.

.PARAMETER DisableScreensaver
    Nonaktifkan screensaver Android TV. Default: aktif (-DisableScreensaver:$false
    untuk melewati).

.PARAMETER SkipInstall
    Hanya kumpulkan data, jangan pasang APK.

.EXAMPLE
    .\tools\provision_tv.ps1
    .\tools\provision_tv.ps1 -Serial 192.168.1.20:5555
    .\tools\provision_tv.ps1 -ApkPath "C:\RTSQ TV\rtsq_tv\build\app\outputs\flutter-apk\app-release.apk" -SkipInstall
#>

[CmdletBinding()]
param(
    [string]$ApkPath = "C:\RTSQ TV\rtsq_tv\build\app\outputs\flutter-apk\app-release.apk",
    [string]$Serial = "",
    [bool]$DisableScreensaver = $true,
    [switch]$SkipInstall
)

$ErrorActionPreference = "Stop"

function Write-Step([string]$Message) {
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Invoke-Adb {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
    if ($Serial) {
        & adb -s $Serial @Args
    } else {
        & adb @Args
    }
    if ($LASTEXITCODE -ne 0) {
        throw "adb gagal: adb $($Args -join ' ')"
    }
}

try {
    if (-not (Get-Command adb -ErrorAction SilentlyContinue)) {
        throw "adb tidak ditemukan di PATH. Pasang Android Platform Tools lebih dulu."
    }

    if ($Serial -and $Serial.Contains(":")) {
        Write-Step "Menyambung ke $Serial"
        & adb connect $Serial | Out-Host
    }

    Write-Step "Menunggu perangkat siap"
    if ($Serial) {
        & adb -s $Serial wait-for-device
    } else {
        & adb wait-for-device
    }

    $devices = (& adb devices) -join "`n"
    if ($devices -match "offline") {
        throw "Ada perangkat berstatus offline. Cabut/sambung ulang lalu coba lagi.`n$devices"
    }

    # ---------------------------------------------------------------- info
    Write-Step "Mengumpulkan spesifikasi perangkat"
    $report = [System.Collections.Generic.List[string]]::new()
    $report.Add("RTSQ TV - Laporan Provisioning")
    $report.Add("Waktu: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $report.Add("Serial: $(if ($Serial) { $Serial } else { 'default' })")
    $report.Add("")

    $props = [ordered]@{
        "Model"            = "ro.product.model"
        "Manufacturer"     = "ro.product.manufacturer"
        "Android"          = "ro.build.version.release"
        "SDK"              = "ro.build.version.sdk"
        "Build"            = "ro.build.id"
        "Fingerprint"      = "ro.build.fingerprint"
    }

    foreach ($key in $props.Keys) {
        $value = (Invoke-Adb shell getprop $props[$key]) -join ""
        $report.Add(("{0,-14}: {1}" -f $key, $value.Trim()))
        Write-Host ("{0,-14}: {1}" -f $key, $value.Trim())
    }

    $wmSize = (Invoke-Adb shell wm size) -join " "
    $wmDensity = (Invoke-Adb shell wm density) -join " "
    $report.Add(("{0,-14}: {1}" -f "wm size", $wmSize.Trim()))
    $report.Add(("{0,-14}: {1}" -f "wm density", $wmDensity.Trim()))

    $mem = (Invoke-Adb shell cat /proc/meminfo | Select-String "MemTotal") -join ""
    $report.Add(("{0,-14}: {1}" -f "MemTotal", $mem.Trim()))

    $disk = (Invoke-Adb shell df -h /data | Select-Object -Last 1) -join ""
    $report.Add(("{0,-14}: {1}" -f "Disk /data", $disk.Trim()))

    $screensaver = (Invoke-Adb shell settings get secure screensaver_enabled) -join ""
    $report.Add(("{0,-14}: {1}" -f "screensaver", $screensaver.Trim()))

    # ------------------------------------------------------------- install
    if (-not $SkipInstall) {
        if (-not (Test-Path $ApkPath)) {
            throw "APK tidak ditemukan: $ApkPath"
        }

        Write-Step "Memasang APK ($([math]::Round((Get-Item $ApkPath).Length / 1MB, 1)) MB)"
        Invoke-Adb install -r $ApkPath | Out-Host
        $report.Add("")
        $report.Add("APK dipasang: $ApkPath")
    } else {
        Write-Step "Melewati pemasangan APK (-SkipInstall)"
    }

    # ------------------------------------------------------ screensaver off
    if ($DisableScreensaver) {
        Write-Step "Menonaktifkan screensaver (bisa dikembalikan lewat Settings)"
        try {
            Invoke-Adb shell settings put secure screensaver_enabled 0 | Out-Null
            Invoke-Adb shell settings put system screen_off_timeout 2147483647 | Out-Null
            $report.Add("Screensaver  : dinonaktifkan (screensaver_enabled=0)")
        } catch {
            $report.Add("Screensaver  : gagal dinonaktifkan ($($_.Exception.Message))")
        }
    }

    # --------------------------------------------------------------- launch
    Write-Step "Menjalankan RTSQ TV"
    Invoke-Adb shell am force-stop id.rtsq.tv | Out-Null
    Invoke-Adb shell am start -n id.rtsq.tv/.MainActivity | Out-Host

    Start-Sleep -Seconds 5

    $top = (Invoke-Adb shell dumpsys activity activities |
        Select-String "mResumedActivity|topResumedActivity" |
        Select-Object -First 1) -join ""
    $report.Add("")
    $report.Add("Aktivitas teratas: $($top.Trim())")

    $report.Add("")
    $report.Add("Checklist manual ada di docs/tv-aqua.md bagian 4.3.")

    $outPath = Join-Path $PSScriptRoot "..\docs\tv-aqua-report.txt"
    $report | Set-Content -Path $outPath -Encoding UTF8
    Write-Step "Laporan disimpan: $outPath"

    Write-Host ""
    Write-Host "Selesai. Lanjutkan checklist di docs/tv-aqua.md." -ForegroundColor Green
} catch {
    Write-Host ""
    Write-Host "GAGAL: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
