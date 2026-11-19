# =====================================================================
#  actualizar_tcl.ps1 - Actualiza YatuIPTV en la TCL por ADB (LAN)
#
#  Uso (en el PC del trabajo, con la TCL en la misma red):
#     .\actualizar_tcl.ps1 -Ip 192.168.1.50
#
#  Opciones:
#     -Ip           IP de la TCL (obligatoria)
#     -Port         puerto ADB (5555 por defecto)
#     -ForzarHardware   deja el decodificador en Hardware
#     -SoloVersion  solo muestra la version instalada
#
#  Hace todo: baja ADB si falta, baja el APK ultimo, conecta, instala,
#  abre la app y guarda una captura de pantalla.
# =====================================================================

param(
    [Parameter(Mandatory = $true)][string]$Ip,
    [int]$Port = 5555,
    [switch]$ForzarHardware,
    [switch]$SoloVersion
)

$ErrorActionPreference = 'Continue'
$dir = Join-Path $env:TEMP 'yatu_tcl'
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$target = "${Ip}:$Port"

function Log($msg) { Write-Host "[Yatu] $msg" -ForegroundColor Cyan }

# ---------- ADB ----------
$adb = (Get-Command adb -ErrorAction SilentlyContinue).Source
if (-not $adb) {
    $adb = Join-Path $dir 'platform-tools\adb.exe'
}
if (-not (Test-Path $adb)) {
    Log "Descargando platform-tools (ADB)..."
    $zip = Join-Path $dir 'platform-tools.zip'
    Invoke-WebRequest -Uri 'https://dl.google.com/android/repository/platform-tools-latest-windows.zip' -OutFile $zip -UseBasicParsing
    Expand-Archive -Path $zip -DestinationPath $dir -Force
    $adb = Join-Path $dir 'platform-tools\adb.exe'
}
Log "ADB: $adb"

# ---------- conexion ----------
Log "Conectando a $target ..."
& $adb connect $target | Out-Null
Start-Sleep -Seconds 2

# ---------- version ----------
if ($SoloVersion) {
    & $adb -s $target shell "dumpsys package com.yatu.iptv | grep versionName"
    return
}

# ---------- APK ----------
$apk = Join-Path $dir 'YatuIPTV.apk'
Log "Descargando ultimo APK..."
Invoke-WebRequest -Uri 'https://github.com/iYatuCL/YatuIPTV/releases/latest/download/YatuIPTV.apk' -OutFile $apk -UseBasicParsing
Log "APK: $([math]::Round((Get-Item $apk).Length / 1MB, 1)) MB"

# ---------- instalar ----------
Log "Instalando en la TV..."
& $adb -s $target install -r $apk
if ($LASTEXITCODE -ne 0) { throw "Fallo la instalacion (revisar 'adb devices')" }

# ---------- hardware ----------
if ($ForzarHardware) {
    Log "Dejando decodificador en Hardware..."
    $xml = '<?xml version="1.0" encoding="utf-8" standalone="yes" ?><map><boolean name="decoder_software" value="false" /></map>'
    $tmp = Join-Path $dir 'yatu_player.xml'
    Set-Content -Path $tmp -Value $xml -Encoding UTF8
    & $adb -s $target push $tmp /data/local/tmp/yatu_player.xml | Out-Null
    & $adb -s $target shell "run-as com.yatu.iptv mkdir -p shared_prefs; run-as com.yatu.iptv cp /data/local/tmp/yatu_player.xml shared_prefs/yatu_player.xml"
    Log "Preferencia HW guardada"
}

# ---------- abrir y capturar ----------
Log "Abriendo la app..."
& $adb -s $target shell am force-stop com.yatu.iptv
& $adb -s $target shell "am start -n com.yatu.iptv/.SplashActivity" | Out-Null
Start-Sleep -Seconds 8
& $adb -s $target shell "screencap -p /sdcard/yatu_cap.png" | Out-Null
$cap = Join-Path $dir 'yatu_cap.png'
& $adb -s $target pull /sdcard/yatu_cap.png $cap | Out-Null
& $adb -s $target shell "rm -f /sdcard/yatu_cap.png"

$out = Join-Path ([Environment]::GetFolderPath('Desktop')) 'yatu_cap.png'
Copy-Item $cap $out -Force

Write-Host ""
Log "LISTO"
Write-Host "Version instalada:"
& $adb -s $target shell "dumpsys package com.yatu.iptv | grep versionName"
Write-Host "Captura guardada en: $out"
Write-Host ""
Write-Host "Para probar el video: abri un canal y toca ► (audio/video). Debe decir 'Hardware (Rapido)'." -ForegroundColor Yellow
