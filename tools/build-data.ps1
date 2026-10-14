# Builds data/species.json and data/art-gen<N>.json from PokeAPI.
# Usage: powershell -ExecutionPolicy Bypass -File tools/build-data.ps1 [-Size 300] [-Quality 80]
param(
  [int]$Size = 300,
  [int]$Quality = 80
)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root  = Split-Path -Parent $PSScriptRoot
$cache = Join-Path $PSScriptRoot 'cache'
$art   = Join-Path $cache 'art'
$out   = Join-Path $root 'data'
New-Item -ItemType Directory -Force $art, $out | Out-Null

# Must match --card in index.html: artwork is flattened onto this colour as JPEG.
$cardColor = [System.Drawing.Color]::FromArgb(246, 243, 236)

# Species whose only evolution comes from a regional form, so the artwork shown
# (the default form) does not evolve: Farfetch'd, Mr. Mime, Qwilfish, Corsola, Linoone, Basculin.
$regionalOnlyEvolution = @(83, 122, 211, 222, 264, 550)

$csvBase = 'https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv'
foreach ($f in 'pokemon_species.csv', 'pokemon_species_names.csv') {
  $p = Join-Path $cache $f
  if (-not (Test-Path $p)) { curl.exe -sSfL -o $p "$csvBase/$f"; if ($LASTEXITCODE) { throw "download failed: $f" } }
}

$species = Import-Csv (Join-Path $cache 'pokemon_species.csv') -Encoding UTF8
$names = @{}
Import-Csv (Join-Path $cache 'pokemon_species_names.csv') -Encoding UTF8 |
  Where-Object { $_.local_language_id -eq '9' } |
  ForEach-Object { $names[[int]$_.pokemon_species_id] = $_.name }

$evolvesInto = @{}
foreach ($s in $species) { if ($s.evolves_from_species_id) { $evolvesInto[[int]$s.evolves_from_species_id] = $true } }

# Download any missing artwork in parallel.
$artBase = 'https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork'
$cfg = foreach ($s in $species) {
  $png = Join-Path $art "$($s.id).png"
  if (-not (Test-Path $png)) { "url = `"$artBase/$($s.id).png`"`noutput = `"$($png -replace '\\','/')`"" }
}
if ($cfg) {
  $cfgPath = Join-Path $cache 'curl.cfg'
  [IO.File]::WriteAllText($cfgPath, ($cfg -join "`n"))
  Write-Host "Downloading $(@($cfg).Count) images..."
  curl.exe -sSfL --parallel --parallel-max 16 -K $cfgPath
  if ($LASTEXITCODE) { throw 'artwork download failed' }
}

$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)

function Convert-Art([string]$path) {
  $src = [System.Drawing.Image]::FromFile($path)
  try {
    $bmp = New-Object System.Drawing.Bitmap $Size, $Size
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear($cardColor)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($src, 0, 0, $Size, $Size)
    $g.Dispose()
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, $jpeg, $encParams)
    $bmp.Dispose()
    'data:image/jpeg;base64,' + [Convert]::ToBase64String($ms.ToArray())
  } finally { $src.Dispose() }
}

$list = New-Object System.Collections.ArrayList
$artByGen = @{}
foreach ($s in $species) {
  $id = [int]$s.id; $gen = [int]$s.generation_id
  [void]$list.Add([pscustomobject]@{
    id   = $id
    name = $names[$id]
    gen  = $gen
    pre  = [bool]($evolvesInto[$id] -and ($regionalOnlyEvolution -notcontains $id))
  })
  if (-not $artByGen[$gen]) { $artByGen[$gen] = [ordered]@{} }
  $artByGen[$gen]["$id"] = Convert-Art (Join-Path $art "$id.png")
}

$utf8 = New-Object System.Text.UTF8Encoding $false
[IO.File]::WriteAllText((Join-Path $out 'species.json'), [string](ConvertTo-Json -InputObject $list.ToArray() -Compress), $utf8)
foreach ($gen in $artByGen.Keys) {
  $json = [string](ConvertTo-Json -InputObject $artByGen[$gen] -Compress)
  [IO.File]::WriteAllText((Join-Path $out "art-gen$gen.json"), $json, $utf8)
}
Write-Host "Wrote $($list.Count) species to $out"
