<#
.SYNOPSIS
    Packages the skin as Installer\Trading212-<version>.rmskin.

.DESCRIPTION
    Builds the same format as Rainmeter's Skin Packager: a zip containing
    RMSKIN.ini and Skins\Trading212\..., followed by a 16-byte footer
    (zip size as Int64, a flags byte, then "RMSKIN\0").

    Version and Author are read from [Metadata] in Portfolio.ini.
    Settings.inc is listed in VariableFiles, so reinstalling or upgrading
    keeps the user's API key and secret.

.EXAMPLE
    .\build.ps1
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

$skin = 'Trading212'
$source = Join-Path $PSScriptRoot $skin
$ini = Join-Path $source 'Portfolio\Portfolio.ini'

function Get-Metadata([string]$key) {
    $match = Select-String -LiteralPath $ini -Pattern "^$key=(.+)$" | Select-Object -First 1
    if (-not $match) { throw "No $key= found in $ini" }
    $match.Matches[0].Groups[1].Value.Trim()
}
$version = Get-Metadata 'Version'
$author = Get-Metadata 'Author'

# Refuse to package credentials.
$settings = Get-Content -LiteralPath (Join-Path $source '@Resources\Settings.inc')
if ($settings -match '^Api(Key|Secret)=\S') {
    throw 'Settings.inc contains an API key or secret. Clear them before building.'
}

$rmskinIni = @"
[rmskin]
Name=$skin
Author=$author
Version=$version
LoadType=Skin
Load=$skin\Portfolio\Portfolio.ini
VariableFiles=$skin\@Resources\Settings.inc
MinimumRainmeter=4.0.0
MinimumWindows=5.1
"@

$installer = Join-Path $PSScriptRoot 'Installer'
New-Item -ItemType Directory -Force -Path $installer | Out-Null
$out = Join-Path $installer "$skin-$version.rmskin"
if (Test-Path -LiteralPath $out) { Remove-Item -LiteralPath $out }

# Runtime state never goes into the package; only the folder placeholder.
$files = Get-ChildItem -LiteralPath $source -Recurse -File -Force |
    Where-Object { $_.FullName -notlike "*\@Resources\State\*" -or $_.Name -eq '.gitkeep' }

$stream = [IO.File]::Open($out, [IO.FileMode]::CreateNew)
try {
    $zip = New-Object IO.Compression.ZipArchive($stream, [IO.Compression.ZipArchiveMode]::Create, $true)
    try {
        $entry = $zip.CreateEntry('RMSKIN.ini')
        $writer = New-Object IO.StreamWriter($entry.Open(), (New-Object Text.ASCIIEncoding))
        $writer.Write($rmskinIni)
        $writer.Dispose()

        foreach ($file in $files) {
            $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
            $entry = $zip.CreateEntry("Skins/$skin/$relative")
            $in = [IO.File]::OpenRead($file.FullName)
            $to = $entry.Open()
            $in.CopyTo($to)
            $to.Dispose()
            $in.Dispose()
        }
    } finally {
        $zip.Dispose()
    }

    $zipSize = $stream.Length
    [byte[]]$footer = [BitConverter]::GetBytes([Int64]$zipSize) + [byte]0 + [Text.Encoding]::ASCII.GetBytes("RMSKIN`0")
    $stream.Write($footer, 0, $footer.Length)
} finally {
    $stream.Dispose()
}

Write-Host "Built $out" -ForegroundColor Green
