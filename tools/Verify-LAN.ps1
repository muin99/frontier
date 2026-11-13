param([string]$Executable = '', [switch]$Release)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $Executable) { $Executable = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe' }
$hostLog = Join-Path $projectRoot 'build/lan-host-checked.log'
$clientLog = Join-Path $projectRoot 'build/lan-client-checked.log'
$baseArguments = @('--headless','--max-fps','60','--quit-after','3000')
if (-not $Release) { $baseArguments += @('--path',('"' + (Join-Path $projectRoot 'game') + '"')) }
# Start-Process needs explicit quotes around path arguments that may contain spaces.
$quotedHost = '"' + $hostLog + '"'
$quotedClient = '"' + $clientLog + '"'
$hostProcess = Start-Process -FilePath $Executable -ArgumentList ($baseArguments + @('--log-file',$quotedHost,'--','--lan-host-test')) -WindowStyle Hidden -PassThru
Start-Sleep -Seconds 3
$clientProcess = Start-Process -FilePath $Executable -ArgumentList ($baseArguments + @('--log-file',$quotedClient,'--','--lan-client-test')) -WindowStyle Hidden -PassThru
if (-not $clientProcess.WaitForExit(45000)) { throw 'LAN client exceeded test timeout' }
if (-not $hostProcess.WaitForExit(45000)) { throw 'LAN host exceeded test timeout' }
foreach ($entry in @(@($hostLog,'LAN HOST INTEGRATION: PASS'),@($clientLog,'LAN CLIENT INTEGRATION: PASS'))) {
    $output = Get-Content -Raw $entry[0]
    Write-Output $output
    if ($output -match 'ERROR:|SCRIPT ERROR|leaked at exit' -or $output -notmatch $entry[1]) { throw "LAN check failed: $($entry[0])" }
}
