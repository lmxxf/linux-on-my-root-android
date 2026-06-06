# Android probe -- run in Windows PowerShell (phone connected via USB, adb authorized)
#   cd Z:\home\lmxxf\work\linux-on-openharmony
#   powershell -ExecutionPolicy Bypass -File .\android-probe.ps1
# English-only to avoid GBK garbling. Paste all output back to Suzaku.

$ErrorActionPreference = "Continue"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$probeSh = Join-Path $scriptDir "android-probe.sh"

Write-Host "==================== ADB DEVICES ====================" -ForegroundColor Cyan
adb devices

if (-not (Test-Path $probeSh)) {
    Write-Host "[ERROR] android-probe.sh not found next to this script" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "==================== PUSH PROBE ====================" -ForegroundColor Cyan
adb push $probeSh /data/local/tmp/android-probe.sh

Write-Host ""
Write-Host "==================== RUN (plain shell, no root) ====================" -ForegroundColor Cyan
Write-Host "First pass: run without su, so we can see device info even if root is missing." -ForegroundColor Yellow
adb shell "sh /data/local/tmp/android-probe.sh"

Write-Host ""
Write-Host "==================== TRY ROOT VARIANTS ====================" -ForegroundColor Cyan
Write-Host "Now testing how to get root on THIS device. Watch the phone for an auth popup." -ForegroundColor Yellow

Write-Host "`n--- try: su -c (string form) ---" -ForegroundColor DarkCyan
adb shell "su -c 'id'"

Write-Host "`n--- try: su 0 (toybox style) ---" -ForegroundColor DarkCyan
adb shell "su 0 id"

Write-Host "`n--- try: echo id | su ---" -ForegroundColor DarkCyan
adb shell "echo id | su"

Write-Host "`n--- try: KernelSU fixed path ---" -ForegroundColor DarkCyan
adb shell "/data/adb/ksu/bin/su -c 'id'"

Write-Host ""
Write-Host "==================== DONE: paste EVERYTHING back ====================" -ForegroundColor Green
