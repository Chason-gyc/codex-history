param(
    [string]$CodexHome = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }),
    [switch]$NoPath
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$sourceSkill = Join-Path $repoRoot 'skills\codex-history'
if (-not (Test-Path -LiteralPath $sourceSkill)) {
    throw "Cannot find skill source: $sourceSkill"
}

$targetSkills = Join-Path $CodexHome 'skills'
$targetSkill = Join-Path $targetSkills 'codex-history'
New-Item -ItemType Directory -Force -Path $targetSkills | Out-Null

if (Test-Path -LiteralPath $targetSkill) {
    Remove-Item -LiteralPath $targetSkill -Recurse -Force
}
Copy-Item -LiteralPath $sourceSkill -Destination $targetSkill -Recurse

$scriptsDir = Join-Path $targetSkill 'scripts'
$commandDir = Join-Path $env:APPDATA 'npm'
New-Item -ItemType Directory -Force -Path $commandDir | Out-Null

$shim = '@echo off' + "`r`n" + 'powershell -ExecutionPolicy Bypass -File "' + (Join-Path $scriptsDir 'codex-history-cli.ps1') + '" %*' + "`r`n"
foreach ($name in @('codex-history.cmd','chistory.cmd','historySession.cmd')) {
    Set-Content -Encoding ASCII -LiteralPath (Join-Path $commandDir $name) -Value $shim
}

if (-not $NoPath) {
    $userPath = [Environment]::GetEnvironmentVariable('Path','User')
    $parts = @()
    if ($userPath) { $parts = $userPath -split ';' | Where-Object { $_ } }
    if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $commandDir.TrimEnd('\') })) {
        $newPath = if ($userPath) { $userPath.TrimEnd(';') + ';' + $commandDir } else { $commandDir }
        [Environment]::SetEnvironmentVariable('Path', $newPath, 'User')
    }
}

Write-Output "Installed skill: $targetSkill"
Write-Output "Installed commands: $commandDir\codex-history.cmd, $commandDir\chistory.cmd, $commandDir\historySession.cmd"
Write-Output 'Open a new terminal and run: chistory'
