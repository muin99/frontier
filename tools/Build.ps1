param([switch]$SkipArchive)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
& (Join-Path $PSScriptRoot 'Ensure-Engine.ps1') -ExportTemplate
$enginePath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
$output = Join-Path $projectRoot 'build/windows-v13'
New-Item -ItemType Directory -Force -Path $output | Out-Null
& $enginePath --headless --editor --path (Join-Path $projectRoot 'game') --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Source import failed' }
& $enginePath --headless --path (Join-Path $projectRoot 'game') --export-release 'Windows Desktop' (Join-Path $output 'Mohashunnyo.exe')
if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'godot/LICENSE.txt') -Destination (Join-Path $output 'GODOT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'godot/COPYRIGHT.txt') -Destination (Join-Path $output 'GODOT-COPYRIGHT.txt') -Force
foreach ($file in @('Play.cmd','Play-Compatible.cmd','START-HERE.txt','JUDGE_GUIDE.md','RELEASE_VALIDATION.md','README.md')) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $output -Force
}
New-Item -ItemType Directory -Force -Path (Join-Path $output 'tools'),(Join-Path $output 'docs') | Out-Null
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Play.ps1') -Destination (Join-Path $output 'tools/Play.ps1') -Force
Get-ChildItem -LiteralPath (Join-Path $projectRoot 'docs') -Filter '*.md' | Copy-Item -Destination (Join-Path $output 'docs') -Force
$files = @('Mohashunnyo.exe','Mohashunnyo.pck') | ForEach-Object {
    $path = Join-Path $output $_
    [ordered]@{name=$_;sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $path).Length}
}
[ordered]@{version='0.13.0';files=@($files)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $output 'runtime-integrity.json') -Encoding UTF8
if (-not $SkipArchive) {
    $archive = Join-Path $projectRoot 'build/Mohashunnyo-Windows.zip'
    Compress-Archive -Path (Join-Path $output '*') -DestinationPath $archive -Force
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash.ToLowerInvariant()
    [ordered]@{tag='v0.13.0';url='https://github.com/muin99/frontier/releases/download/v0.13.0/Mohashunnyo-Windows.zip';sha256=$hash;files=@($files)} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'release-manifest.json') -Encoding UTF8
    Write-Output ('WINDOWS PACKAGE: ' + $archive + ' SHA256 ' + $hash)
}
