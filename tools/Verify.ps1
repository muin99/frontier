$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$enginePath = Join-Path $PSScriptRoot 'godot/Godot_v4.7.2-stable_win64_console.exe'
$gamePath = Join-Path $projectRoot 'game'
function Invoke-GameCheck($name, $arguments, $sentinel) {
    $log = Join-Path $projectRoot "build/$name.log"
    & $enginePath @arguments *> $log
    $exitCode = $LASTEXITCODE
    $output = Get-Content -Raw $log
    Write-Output $output
    if ($exitCode -ne 0 -or $output -match 'SCRIPT ERROR:|ERROR:|leaked at exit' -or $output -notmatch $sentinel) {
        throw "$name failed; see $log"
    }
}
New-Item -ItemType Directory -Force (Join-Path $projectRoot 'build') | Out-Null
Invoke-GameCheck 'beginner-learning' @('--headless','--path',$gamePath,'--quit-after','10000','--','--learning-test') 'BEGINNER LEARNING: PASS'
Invoke-GameCheck 'guided-playthrough' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','35000','--','--guided-test') 'GUIDED PLAYTHROUGH: PASS'
Invoke-GameCheck 'mission-review-check' @('--headless','--path',$gamePath,'--script','res://scripts/test_mission_review.gd') 'MISSION REVIEW: PASS'
Invoke-GameCheck 'expedition-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','30000','--','--expedition-test') 'EXPEDITION INTEGRATION: PASS'
Invoke-GameCheck 'spaceport-check' @('--headless','--path',$gamePath,'res://scenes/spaceport.tscn','--quit-after','12000','--','--smoke') 'SMOKE RESULT: PASS'
Invoke-GameCheck 'ground-transfer-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--script','res://scripts/test_ground_transfer.gd','--quit-after','30000','--','--ground-transfer-test') 'GROUND TRANSFER: PASS'
Invoke-GameCheck 'exploration-generator-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--script','res://scripts/test_exploration.gd','--quit-after','10000') 'EXPLORATION GENERATOR: PASS'
Invoke-GameCheck 'regional-traversal-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--script','res://scripts/test_traverse_regions.gd','--quit-after','160000') 'REGIONAL TRAVERSAL: PASS'

Invoke-GameCheck 'frontier-stream-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','18000','--','--frontier-test') 'FRONTIER INTEGRATION: PASS'
Invoke-GameCheck 'outpost-systems-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','12000','--','--outpost-test') 'OUTPOST INTEGRATION: PASS'
Invoke-GameCheck 'campaign-check' @('--headless','--fixed-fps','60','--path',$gamePath,'--quit-after','20000','--','--campaign-test') 'CAMPAIGN INTEGRATION: PASS'
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'Verify-LAN.ps1')
if ($LASTEXITCODE -ne 0) { throw 'LAN verification failed' }
