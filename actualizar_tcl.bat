@echo off
set /p IP=IP de la TV TCL: 
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0actualizar_tcl.ps1" -Ip %IP% -ForzarHardware
pause
