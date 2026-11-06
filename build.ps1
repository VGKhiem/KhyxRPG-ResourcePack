# Build KhyxRPG skill-icon resource pack from raw\<class>_<key>.png (flat #FF00FF background).
# Output: resourcepack\pack\ (source tree) and resourcepack\KhyxRPG-Skills.zip
Add-Type -AssemblyName System.Drawing
$root = $PSScriptRoot
$raw = Join-Path $root 'raw'
$pack = Join-Path $root 'pack'
$size = 32
$texDir = Join-Path $pack 'assets\khyxrpg\textures\item\skill'
$modelDir = Join-Path $pack 'assets\khyxrpg\models\item\skill'
$itemDir = Join-Path $pack 'assets\khyxrpg\items\skill'
foreach ($d in $texDir, $modelDir, $itemDir) { New-Item -ItemType Directory -Force $d | Out-Null }

function Convert-Icon([string]$src, [string]$dst) {
    $bmp = New-Object System.Drawing.Bitmap($src)
    try {
        $w = $bmp.Width; $h = $bmp.Height
        $minX = $w; $minY = $h; $maxX = -1; $maxY = -1
        $mask = New-Object 'bool[,]' $w, $h
        for ($y = 0; $y -lt $h; $y++) {
            for ($x = 0; $x -lt $w; $x++) {
                $c = $bmp.GetPixel($x, $y)
                $isBg = ($c.R -gt 150 -and $c.B -gt 150 -and $c.G -lt 110 -and ([math]::Abs($c.R - $c.B) -lt 90))
                if (-not $isBg) {
                    $mask[$x, $y] = $true
                    if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }
                    if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y }
                }
            }
        }
        if ($maxX -lt 0) { throw "No foreground in $src" }
        $cw = $maxX - $minX + 1; $ch = $maxY - $minY + 1
        $side = [math]::Max($cw, $ch)
        $pad = [int]($side * 0.04)
        $canvas = $side + 2 * $pad
        $sq = New-Object System.Drawing.Bitmap($canvas, $canvas, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $ox = $pad + [int](($side - $cw) / 2); $oy = $pad + [int](($side - $ch) / 2)
        for ($y = 0; $y -lt $ch; $y++) {
            for ($x = 0; $x -lt $cw; $x++) {
                if ($mask[($minX + $x), ($minY + $y)]) {
                    $sq.SetPixel($ox + $x, $oy + $y, $bmp.GetPixel($minX + $x, $minY + $y))
                }
            }
        }
        $out = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $g = [System.Drawing.Graphics]::FromImage($out)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $g.DrawImage($sq, 0, 0, $size, $size)
        $g.Dispose()
        for ($y = 0; $y -lt $size; $y++) {
            for ($x = 0; $x -lt $size; $x++) {
                $c = $out.GetPixel($x, $y)
                if ($c.A -lt 128) { $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0)) }
                else { $out.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(255, $c.R, $c.G, $c.B)) }
            }
        }
        $out.Save($dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $out.Dispose(); $sq.Dispose()
    } finally { $bmp.Dispose() }
}

$utf8 = New-Object System.Text.UTF8Encoding($false)
foreach ($f in Get-ChildItem $raw -File | Where-Object { $_.Extension -in '.png','.jpg' }) {
    $name = $f.BaseName
    Convert-Icon $f.FullName (Join-Path $texDir "$name.png")
    [IO.File]::WriteAllText((Join-Path $modelDir "$name.json"), "{`"parent`":`"minecraft:item/generated`",`"textures`":{`"layer0`":`"khyxrpg:item/skill/$name`"}}", $utf8)
    [IO.File]::WriteAllText((Join-Path $itemDir "$name.json"), "{`"model`":{`"type`":`"minecraft:model`",`"model`":`"khyxrpg:item/skill/$name`"}}", $utf8)
}

[IO.File]::WriteAllText((Join-Path $pack 'pack.mcmeta'), '{"pack":{"pack_format":64,"supported_formats":[64,999],"description":"KhyxRPG Skill Icons"}}', $utf8)

$zip = Join-Path $root 'KhyxRPG-Skills.zip'
if (Test-Path $zip) { Remove-Item $zip -Force }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$za = [System.IO.Compression.ZipFile]::Open($zip, 'Create')
try {
    foreach ($file in Get-ChildItem $pack -Recurse -File) {
        $rel = $file.FullName.Substring($pack.Length + 1).Replace('\', '/')
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($za, $file.FullName, $rel) | Out-Null
    }
} finally { $za.Dispose() }
"SHA1: " + (Get-FileHash $zip -Algorithm SHA1).Hash.ToLower()
