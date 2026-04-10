# Pokreće Operonix Production na webu na fiksnom portu (lokalno testiranje).
# Nakon pokretanja otvori: http://localhost:54888/
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)
Write-Host 'Pokrećem Flutter web-server na http://localhost:54888/ ...' -ForegroundColor Cyan
flutter run -d web-server --web-hostname=localhost --web-port=54888
