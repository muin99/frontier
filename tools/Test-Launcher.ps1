$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$sandbox = Join-Path $root 'build/launcher-test/Judge Source With Spaces'
New-Item -ItemType Directory -Force -Path (Join-Path $sandbox 'tools') | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'Play.cmd') -Destination $sandbox -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Play.ps1') -Destination (Join-Path $sandbox 'tools/Play.ps1') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'release-manifest.json') -Destination (Join-Path $sandbox 'tools/release-manifest.json') -Force
$script = Join-Path $sandbox 'tools/Play.ps1'
$archive = Join-Path $root 'build/Mohashunnyo-Windows.zip'
$powershell = Join-Path $env:SystemRoot 'System32/WindowsPowerShell/v1.0/powershell.exe'
$previousPath = $env:Path
try {
    # Only standard Windows tools in PATH: no Python, Godot, FFmpeg or Git needed.
    $env:Path = (Join-Path $env:SystemRoot 'System32') + ';' + $env:SystemRoot
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $script -PrepareOnly -ArchivePath $archive
    if ($LASTEXITCODE -ne 0) { throw 'Fresh source preparation failed' }
    $manifest = Get-Content -Raw -LiteralPath (Join-Path $sandbox 'tools/release-manifest.json') | ConvertFrom-Json
    $runtime = Join-Path $sandbox ('.runtime/' + $manifest.tag)
    if (-not (Test-Path -LiteralPath (Join-Path $runtime 'Mohashunnyo.exe'))) { throw 'Runtime not installed' }
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $script -PrepareOnly
    if ($LASTEXITCODE -ne 0) { throw 'Offline cached preparation failed' }
    # Damage only this isolated test copy, then verify automatic repair.
    Set-Content -LiteralPath (Join-Path $runtime 'Mohashunnyo.pck') -Value 'corrupt test copy' -Encoding ASCII
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $script -PrepareOnly -ArchivePath $archive
    if ($LASTEXITCODE -ne 0) { throw 'Damaged-runtime recovery failed' }
    $manifest.tag += '-bad-hash-test'; $manifest.sha256 = '0' * 64
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $sandbox 'tools/release-manifest.json') -Encoding UTF8
    & $powershell -NoProfile -ExecutionPolicy Bypass -File $script -PrepareOnly -ArchivePath $archive
    if ($LASTEXITCODE -eq 0) { throw 'Bad archive checksum was accepted' }
    Write-Output 'LAUNCHER CHECK: PASS / clean folder with spaces, Windows-only PATH, offline reuse, damaged runtime repair, bad checksum rejected'
} finally { $env:Path = $previousPath }
