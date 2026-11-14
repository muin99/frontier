param([switch]$PrepareOnly, [switch]$ForceCompatibility, [string]$ArchivePath)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$gameArguments = @($args)
$cacheRoot = Join-Path $projectRoot '.runtime'

function Assert-Runtime($directory, $files) {
    foreach ($file in $files) {
        $path = Join-Path $directory $file.name
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return $false }
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $file.sha256) { return $false }
    }
    return $true
}

function Assert-CachePath([string]$path) {
    $absolute = [IO.Path]::GetFullPath($path)
    $prefix = [IO.Path]::GetFullPath($cacheRoot) + [IO.Path]::DirectorySeparatorChar
    if (-not $absolute.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe runtime cache path.' }
    return $absolute
}

try {
    $bundledExe = Join-Path $projectRoot 'Mohashunnyo.exe'
    $integrityPath = Join-Path $projectRoot 'runtime-integrity.json'
    if ((Test-Path -LiteralPath $bundledExe) -and (Test-Path -LiteralPath $integrityPath)) {
        $integrity = Get-Content -Raw -LiteralPath $integrityPath | ConvertFrom-Json
        if (-not (Assert-Runtime $projectRoot $integrity.files)) { throw 'The game package is incomplete or damaged. Extract the full ZIP again.' }
        $runtime = $projectRoot
    } else {
        $manifestPath = Join-Path $PSScriptRoot 'release-manifest.json'
        if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'The download manifest is missing. Please download the Windows ZIP from the repository Releases page.' }
        $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
        if ($manifest.url -notmatch '^https://github\.com/muin99/frontier/releases/download/[^/]+/Mohashunnyo-Windows\.zip$') { throw 'Unexpected game download address.' }
        $runtime = Assert-CachePath (Join-Path $cacheRoot $manifest.tag)
        if (-not (Assert-Runtime $runtime $manifest.files)) {
            Write-Host 'Preparing Mohashunnyo. No Python, editor, or installation is needed.'
            Write-Host 'Downloading the verified Windows game. This is needed only once.'
            New-Item -ItemType Directory -Force -Path $cacheRoot | Out-Null
            $unique = [Guid]::NewGuid().ToString('N')
            $archive = Assert-CachePath (Join-Path $cacheRoot ($unique + '.zip'))
            $stage = Assert-CachePath (Join-Path $cacheRoot ($unique + '.stage'))
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            if ($ArchivePath) { Copy-Item -LiteralPath $ArchivePath -Destination $archive }
            else { Invoke-WebRequest -UseBasicParsing -Uri $manifest.url -OutFile $archive }
            if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $manifest.sha256) { throw 'Download verification failed. Run Play.cmd again to retry safely.' }
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $zip = [IO.Compression.ZipFile]::OpenRead($archive)
            try {
                $prefix = $stage + [IO.Path]::DirectorySeparatorChar
                foreach ($entry in $zip.Entries) {
                    $target = [IO.Path]::GetFullPath((Join-Path $stage $entry.FullName))
                    if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe path in game archive.' }
                }
            } finally { $zip.Dispose() }
            Expand-Archive -LiteralPath $archive -DestinationPath $stage
            if (-not (Assert-Runtime $stage $manifest.files)) { throw 'The downloaded game did not pass integrity checks.' }
            if (Test-Path -LiteralPath $runtime) {
                $previous = Assert-CachePath ($runtime + '.previous-' + $unique)
                Move-Item -LiteralPath $runtime -Destination $previous
            }
            Move-Item -LiteralPath $stage -Destination $runtime
            Remove-Item -LiteralPath $archive
        }
    }
    if ($PrepareOnly) { Write-Output ('READY: ' + $runtime); exit 0 }
    $logDirectory = Join-Path $env:LOCALAPPDATA 'Mohashunnyo/launcher'
    New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    $log = Join-Path $logDirectory 'game.log'
    $launchArguments = @('--log-file', $log) + $gameArguments
    if ($ForceCompatibility) { $launchArguments += @('--rendering-method','gl_compatibility') }
    function Invoke-Game($arguments) {
        $quoted = @($arguments | ForEach-Object { '"' + ([string]$_).Replace('"','\"') + '"' }) -join ' '
        $process = Start-Process -FilePath (Join-Path $runtime 'Mohashunnyo.exe') -ArgumentList $quoted -WorkingDirectory $runtime -PassThru
        $process.WaitForExit(); $process.Refresh()
        return $process.ExitCode
    }
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-Game $launchArguments
    if ($result -ne 0 -and $watch.Elapsed.TotalSeconds -lt 30 -and -not $ForceCompatibility) {
        Write-Host 'Trying the compatible graphics mode for this computer...'
        $result = Invoke-Game ($launchArguments + @('--rendering-method','gl_compatibility'))
    }
    if ($result -ne 0) { throw ('The game could not start. Please try Play-Compatible.cmd. Diagnostic log: ' + $log) }
    exit 0
} catch {
    Write-Host ''
    Write-Host ('Could not start Mohashunnyo: ' + $_.Exception.Message) -ForegroundColor Yellow
    Write-Host 'For first-time downloads, check the Internet connection. The Windows release ZIP works offline after extraction.'
    exit 1
}
