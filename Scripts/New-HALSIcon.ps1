#==========================================================
# Build Assets\HALS.ico from Assets\HALS.png
#==========================================================

[CmdletBinding()]
param(
    [string]$PngPath = "",
    [string]$IcoPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = Split-Path -Parent $PSScriptRoot
if (-not $PngPath) { $PngPath = Join-Path $RepoRoot "Assets\HALS.png" }
if (-not $IcoPath) { $IcoPath = Join-Path $RepoRoot "Assets\HALS.ico" }

if (-not (Test-Path -LiteralPath $PngPath)) {
    throw "PNG not found: $PngPath"
}

Add-Type -AssemblyName System.Drawing

$Sizes = @(16, 32, 48, 256)
$SrcImg = [System.Drawing.Image]::FromFile($PngPath)
$Images = New-Object System.Collections.Generic.List[byte[]]
$SizeList = New-Object System.Collections.Generic.List[int]

try {
    foreach ($Size in $Sizes) {
        $Bmp = New-Object System.Drawing.Bitmap $Size, $Size
        $Graphics = [System.Drawing.Graphics]::FromImage($Bmp)
        try {
            $Graphics.Clear([System.Drawing.Color]::Transparent)
            $Graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
            $Graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
            $Graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
            $Graphics.DrawImage($SrcImg, 0, 0, $Size, $Size)
        }
        finally {
            $Graphics.Dispose()
        }

        $PngStream = New-Object System.IO.MemoryStream
        try {
            $Bmp.Save($PngStream, [System.Drawing.Imaging.ImageFormat]::Png)
            $Images.Add($PngStream.ToArray())
            $SizeList.Add($Size)
        }
        finally {
            $PngStream.Dispose()
            $Bmp.Dispose()
        }
    }
}
finally {
    $SrcImg.Dispose()
}

$Memory = New-Object System.IO.MemoryStream
$Writer = New-Object System.IO.BinaryWriter $Memory
try {
    $Writer.Write([uint16]0)
    $Writer.Write([uint16]1)
    $Writer.Write([uint16]$Images.Count)

    $Offset = 6 + (16 * $Images.Count)
    for ($i = 0; $i -lt $Images.Count; $i++) {
        $Size = $SizeList[$i]
        $WidthByte = if ($Size -ge 256) { [byte]0 } else { [byte]$Size }
        $HeightByte = if ($Size -ge 256) { [byte]0 } else { [byte]$Size }
        $Writer.Write($WidthByte)
        $Writer.Write($HeightByte)
        $Writer.Write([byte]0)
        $Writer.Write([byte]0)
        $Writer.Write([uint16]1)
        $Writer.Write([uint16]32)
        $Writer.Write([uint32]$Images[$i].Length)
        $Writer.Write([uint32]$Offset)
        $Offset += $Images[$i].Length
    }

    foreach ($Bytes in $Images) {
        $Writer.Write($Bytes)
    }

    $Writer.Flush()
    [System.IO.File]::WriteAllBytes($IcoPath, $Memory.ToArray())
}
finally {
    $Writer.Dispose()
    $Memory.Dispose()
}

Write-Host "Wrote $IcoPath"
Get-Item -LiteralPath $IcoPath | Select-Object FullName, Length
