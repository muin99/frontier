param([string]$Executable = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $Executable) { $Executable = Join-Path $root 'build/windows-v13/Mohashunnyo.exe' }
foreach ($check in @(@('adventure','--adventure-test','ADVENTURE SYSTEMS: PASS'),@('learning','--learning-test','BEGINNER LEARNING: PASS'),@('guided','--guided-test','GUIDED PLAYTHROUGH: PASS'))) {
    $log = Join-Path $root ('build/release-' + $check[0] + '.log')
    $process = Start-Process -FilePath $Executable -ArgumentList @('--headless','--fixed-fps','60','--quit-after','40000','--log-file',('"'+$log+'"'),'--',$check[1]) -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) { throw ('Release test timed out: '+$check[0]) }
    $output = Get-Content -Raw -LiteralPath $log
    Write-Output $output
    if ($output -match 'ERROR:|SCRIPT ERROR:|FAIL|leaked at exit' -or $output -notmatch $check[2]) { throw ('Release test failed: '+$check[0]) }
}
& (Join-Path $PSScriptRoot 'Verify-LAN.ps1') -Executable $Executable -Release
# Verify-LAN is a PowerShell script: it throws on failure and does not set LASTEXITCODE.
Write-Output 'PACKAGED RELEASE: PASS / adventure, learning, complete first mission and host/client LAN'
