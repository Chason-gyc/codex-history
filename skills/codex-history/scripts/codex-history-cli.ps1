param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$ArgsList
)

$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'codex-history.ps1'

function Invoke-History([string[]]$Arguments) {
    & powershell -ExecutionPolicy Bypass -File $script @Arguments
}

if (-not $ArgsList -or $ArgsList.Count -eq 0) {
    Invoke-History @('-Mode','pick','-All','-Limit','20')
    exit $LASTEXITCODE
}

$cmd = $ArgsList[0].ToLowerInvariant()
$rest = @()
if ($ArgsList.Count -gt 1) { $rest = $ArgsList[1..($ArgsList.Count - 1)] }

switch ($cmd) {
    'today' { Invoke-History @('-Mode','pick','-Day','today','-Limit','20'); break }
    'yesterday' { Invoke-History @('-Mode','pick','-Day','yesterday','-Limit','20'); break }
    'all' { Invoke-History @('-Mode','pick','-All','-Limit','50'); break }
    'list' {
        $dayArgs = @('-Mode','list','-All','-Limit','20')
        if ($rest.Count -ge 1 -and @('today','yesterday','all') -contains $rest[0].ToLowerInvariant()) {
            if ($rest[0].ToLowerInvariant() -eq 'all') { $dayArgs = @('-Mode','list','-All','-Limit','20') }
            else { $dayArgs = @('-Mode','list','-Day',$rest[0],'-Limit','20') }
        }
        if ($rest.Count -ge 2 -and $rest[1] -match '^\d+$') { $dayArgs[-1] = $rest[1] }
        Invoke-History $dayArgs
        break
    }
    'show' {
        if ($rest.Count -lt 1) { throw 'Usage: codex-history show <session-id>' }
        Invoke-History @('-Mode','show','-Id',$rest[0])
        break
    }
    'summary' {
        if ($rest.Count -lt 1) { throw 'Usage: codex-history summary <session-id>' }
        Invoke-History @('-Mode','summarize','-Id',$rest[0])
        break
    }
    'summarize' {
        if ($rest.Count -lt 1) { throw 'Usage: codex-history summarize <session-id>' }
        Invoke-History @('-Mode','summarize','-Id',$rest[0])
        break
    }
    'resume' {
        if ($rest.Count -lt 1) { throw 'Usage: codex-history resume <session-id>' }
        Invoke-History @('-Mode','resume','-Id',$rest[0],'-NewWindow')
        break
    }
    'help' {
        Write-Output 'Usage:'
        Write-Output '  codex-history                         Pick from recent sessions and resume'
        Write-Output '  codex-history today|yesterday|all     Pick from that range and resume'
        Write-Output '  codex-history list [today|yesterday|all] [limit]'
        Write-Output '  codex-history show <session-id>'
        Write-Output '  codex-history summary <session-id>'
        Write-Output '  codex-history resume <session-id>'
        Write-Output 'Aliases: chistory, historySession'
        break
    }
    default {
        if ($cmd -match '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
            Invoke-History @('-Mode','resume','-Id',$cmd,'-NewWindow')
        } else {
            throw "Unknown command: $cmd. Run: codex-history help"
        }
    }
}
