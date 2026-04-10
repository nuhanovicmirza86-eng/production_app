# Generates web/favicon.png and web/icons/*.png from the canonical app icon.
# READS ONLY from branding/ — never writes there.
$ErrorActionPreference = 'Stop'
$appRoot = Split-Path $PSScriptRoot -Parent
$src = Join-Path $appRoot 'branding\operonix_production_icon.PNG'
if (-not (Test-Path $src)) {
  Write-Error "Missing source icon: $src"
}

Add-Type -AssemblyName System.Drawing

function Export-SquareIcon {
  param(
    [System.Drawing.Image]$Source,
    [int]$Size,
    [string]$OutPath
  )
  $bmp = New-Object System.Drawing.Bitmap -ArgumentList $Size, $Size
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $g.DrawImage($Source, 0, 0, $Size, $Size)
  $dir = Split-Path $OutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $bmp.Save($OutPath, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose()
  $bmp.Dispose()
}

$img = [System.Drawing.Image]::FromFile((Resolve-Path $src))
try {
  $web = Join-Path $appRoot 'web'
  Export-SquareIcon -Source $img -Size 32 -OutPath (Join-Path $web 'favicon.png')
  $icons = Join-Path $web 'icons'
  Export-SquareIcon -Source $img -Size 192 -OutPath (Join-Path $icons 'Icon-192.png')
  Export-SquareIcon -Source $img -Size 512 -OutPath (Join-Path $icons 'Icon-512.png')
  Copy-Item (Join-Path $icons 'Icon-192.png') (Join-Path $icons 'Icon-maskable-192.png') -Force
  Copy-Item (Join-Path $icons 'Icon-512.png') (Join-Path $icons 'Icon-maskable-512.png') -Force
  Write-Host "Web icons updated from branding (web/ only)."
}
finally {
  $img.Dispose()
}
