param([switch]$ExportTemplate)
$ErrorActionPreference = 'Stop'
$directory = Join-Path $PSScriptRoot 'godot'
New-Item -ItemType Directory -Force -Path $directory | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Add-Type -AssemblyName System.IO.Compression.FileSystem
$baseUrl = 'https://github.com/godotengine/godot/releases/download/4.7.2-stable/'
$engine = Join-Path $directory 'Godot_v4.7.2-stable_win64_console.exe'
if (-not (Test-Path -LiteralPath $engine)) {
    Write-Host 'Downloading the portable Godot editor for this source build...'
    $archive = Join-Path $directory 'engine.zip'
    Invoke-WebRequest -UseBasicParsing -Uri ($baseUrl + 'Godot_v4.7.2-stable_win64.exe.zip') -OutFile $archive
    if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne '731980F9608D61333E5BAF54A2EF17210ACC7A538446C0CB9969F002ACA1E953') { throw 'Portable engine verification failed.' }
    $zip = [IO.Compression.ZipFile]::OpenRead($archive)
    try {
        foreach ($name in @('Godot_v4.7.2-stable_win64.exe','Godot_v4.7.2-stable_win64_console.exe')) {
            $entry = @($zip.Entries | Where-Object { $_.Name -eq $name })
            if ($entry.Count -ne 1) { throw 'Unexpected portable-engine archive.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], (Join-Path $directory $name), $true)
        }
    } finally { $zip.Dispose() }
}
foreach ($notice in @('LICENSE.txt','COPYRIGHT.txt')) {
    $path = Join-Path $directory $notice
    if (-not (Test-Path -LiteralPath $path)) {
        Invoke-WebRequest -UseBasicParsing -Uri ('https://raw.githubusercontent.com/godotengine/godot/4.7.2-stable/' + $notice) -OutFile $path
    }
}
if ($ExportTemplate) {
    $templates = Join-Path $directory 'templates'
    $template = Join-Path $templates 'windows_release_x86_64.exe'
    $expected = 'd34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562'
    if (-not (Test-Path -LiteralPath $template) -or (Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -ne $expected) {
        Write-Host 'Downloading official export templates for the first source build (about 1.3 GB)...'
        New-Item -ItemType Directory -Force -Path $templates | Out-Null
        $archive = Join-Path $directory 'export-templates.tpz'
        Invoke-WebRequest -UseBasicParsing -Uri ($baseUrl + 'Godot_v4.7.2-stable_export_templates.tpz') -OutFile $archive
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $entry = @($zip.Entries | Where-Object { $_.FullName -eq 'templates/windows_release_x86_64.exe' })
            if ($entry.Count -ne 1) { throw 'Windows template missing from official archive.' }
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], $template, $true)
        } finally { $zip.Dispose() }
        if ((Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash -ne $expected) { throw 'Windows export template verification failed.' }
        Remove-Item -LiteralPath $archive
    }
}
Write-Host 'Portable build dependencies ready. No Python or global installation is required.'
