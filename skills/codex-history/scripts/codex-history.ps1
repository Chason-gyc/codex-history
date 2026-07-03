param(
    [ValidateSet('list','summarize','show','resume','pick')]
    [string]$Mode = 'list',

    [string]$Id,

    [ValidateSet('today','yesterday','all')]
    [string]$Day,

    [string]$Date,

    [int]$Limit = 20,

    [switch]$All,

    [switch]$NewWindow,

    [switch]$NoOpen,

    [string]$Prompt
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

function Get-CodexHome {
    if ($env:CODEX_HOME -and (Test-Path -LiteralPath $env:CODEX_HOME)) {
        return (Resolve-Path -LiteralPath $env:CODEX_HOME).Path
    }
    $candidate = Join-Path $env:USERPROFILE '.codex'
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }
    throw 'Cannot find Codex home. Set CODEX_HOME or ensure %USERPROFILE%\.codex exists.'
}

function Get-SessionIdFromFileName([string]$Name) {
    if ($Name -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\.jsonl$') {
        return $matches[1]
    }
    return $null
}

function Get-DateRange([switch]$DefaultAll) {
    if ($Date) {
        $start = Get-Date ($Date + 'T00:00:00')
        return @($start, $start.AddDays(1))
    }
    if ($Day -eq 'today') {
        $start = (Get-Date).Date
        return @($start, $start.AddDays(1))
    }
    if ($Day -eq 'yesterday') {
        $start = (Get-Date).Date.AddDays(-1)
        return @($start, $start.AddDays(1))
    }
    if ($Day -eq 'all' -or $All -or $DefaultAll) {
        return @($null, $null)
    }
    $start = (Get-Date).Date.AddDays(-1)
    return @($start, $start.AddDays(1))
}

function Find-SessionFile([string]$SessionId, [string]$CodexHome) {
    $sessionsDir = Join-Path $CodexHome 'sessions'
    if (-not (Test-Path -LiteralPath $sessionsDir)) {
        throw "No sessions directory found at $sessionsDir"
    }
    $file = Get-ChildItem -Recurse -File -LiteralPath $sessionsDir -Filter '*.jsonl' |
        Where-Object { $_.Name -like "*$SessionId.jsonl" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $file) {
        throw "Session not found: $SessionId"
    }
    return $file
}

function Get-TextFromMessagePayload($Payload) {
    if (-not $Payload.content) { return '' }
    $parts = @()
    foreach ($c in $Payload.content) {
        if ($c.text) { $parts += [string]$c.text }
    }
    return ($parts -join "`n").Trim()
}

function Should-SkipText([string]$Text) {
    if (-not $Text) { return $true }
    if ($Text -like '<environment_context>*') { return $true }
    if ($Text -like '<turn_aborted>*') { return $true }
    if ($Text -like '<permissions instructions>*') { return $true }
    if ($Text -like '<personality_spec>*') { return $true }
    return $false
}

function Read-SessionMeta($File) {
    $meta = [ordered]@{
        id = Get-SessionIdFromFileName $File.Name
        created_at_utc = $null
        modified_local = $File.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        cwd = $null
        file = $File.FullName
        first_user_message = $null
    }
    $foundFirstUser = $false
    Get-Content -Encoding UTF8 -LiteralPath $File.FullName -TotalCount 250 | ForEach-Object {
        try {
            $o = $_ | ConvertFrom-Json
            if ($o.type -eq 'session_meta') {
                if ($o.payload.session_id) { $meta.id = $o.payload.session_id }
                if ($o.payload.timestamp) { $meta.created_at_utc = $o.payload.timestamp }
                if ($o.payload.cwd) { $meta.cwd = $o.payload.cwd }
            } elseif (-not $foundFirstUser -and $o.type -eq 'response_item' -and $o.payload.type -eq 'message' -and $o.payload.role -eq 'user') {
                $text = Get-TextFromMessagePayload $o.payload
                if (-not (Should-SkipText $text)) {
                    if ($text.Length -gt 80) { $text = $text.Substring(0, 80) + '...' }
                    $meta.first_user_message = $text
                    $foundFirstUser = $true
                }
            }
        } catch {}
    }
    return [pscustomobject]$meta
}

function Read-SessionMessages($File, [switch]$IncludeCalls) {
    Get-Content -Encoding UTF8 -LiteralPath $File.FullName | ForEach-Object {
        try {
            $o = $_ | ConvertFrom-Json
            if ($o.type -ne 'response_item') { return }
            $p = $o.payload
            if ($p.type -eq 'message' -and ($p.role -eq 'user' -or $p.role -eq 'assistant')) {
                $text = Get-TextFromMessagePayload $p
                if (-not (Should-SkipText $text)) {
                    [pscustomobject]@{ kind='message'; role=$p.role; text=$text }
                }
            } elseif ($IncludeCalls -and $p.type -eq 'function_call') {
                [pscustomobject]@{ kind='call'; role='tool'; text=$p.name }
            }
        } catch {}
    }
}

function Get-SessionObjects($CodexHome, [switch]$DefaultAll) {
    $sessionsDir = Join-Path $CodexHome 'sessions'
    $range = Get-DateRange -DefaultAll:$DefaultAll
    $start = $range[0]
    $end = $range[1]
    $files = Get-ChildItem -Recurse -File -LiteralPath $sessionsDir -Filter '*.jsonl'
    if ($start -and $end) {
        $files = $files | Where-Object { $_.LastWriteTime -ge $start -and $_.LastWriteTime -lt $end }
    }
    $files |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Limit |
        ForEach-Object { Read-SessionMeta $_ }
}

function New-SessionTableRows($Sessions) {
    $rows = @()
    for ($i = 0; $i -lt $Sessions.Count; $i++) {
        $s = $Sessions[$i]
        $topic = if ($s.first_user_message) { $s.first_user_message } else { '(no user prompt found)' }
        $cwd = if ($s.cwd) { $s.cwd } else { '' }
        $rows += [pscustomobject]@{
            No = $i + 1
            Time = $s.modified_local
            Workdir = $cwd
            Summary = $topic
        }
    }
    return $rows
}

function List-Sessions($CodexHome) {
    $sessions = @(Get-SessionObjects $CodexHome)
    New-SessionTableRows $sessions | Format-Table No, Time, Workdir, Summary -AutoSize -Wrap
}

function Summarize-Session($CodexHome, [string]$SessionId) {
    $file = Find-SessionFile $SessionId $CodexHome
    $meta = Read-SessionMeta $file
    Write-Output "SESSION_ID: $($meta.id)"
    Write-Output "CREATED_UTC: $($meta.created_at_utc)"
    Write-Output "MODIFIED_LOCAL: $($meta.modified_local)"
    Write-Output "CWD: $($meta.cwd)"
    Write-Output "FILE: $($meta.file)"
    Write-Output ''
    Write-Output 'MESSAGES:'
    $messages = @(Read-SessionMessages $file)
    foreach ($m in $messages) {
        $text = $m.text
        if ($text.Length -gt 1200) { $text = $text.Substring(0, 1200) + '...' }
        Write-Output "[$($m.role)] $text"
    }
}

function Show-Session($CodexHome, [string]$SessionId) {
    $file = Find-SessionFile $SessionId $CodexHome
    $meta = Read-SessionMeta $file
    Write-Output "SESSION_ID: $($meta.id)"
    Write-Output "CWD: $($meta.cwd)"
    Write-Output "MODIFIED_LOCAL: $($meta.modified_local)"
    Write-Output ''
    Read-SessionMessages $file | ForEach-Object {
        Write-Output "`n[$($_.role)]"
        Write-Output $_.text
    }
}

function Resume-Session([string]$SessionId, [switch]$OpenWindow) {
    if (-not $SessionId) { throw 'Mode resume requires -Id.' }
    $cmd = "codex.cmd resume $SessionId"
    if ($Prompt) { $cmd = $cmd + ' "' + ($Prompt.Replace('"','\"')) + '"' }
    if ($OpenWindow) {
        Start-Process -FilePath 'cmd.exe' -ArgumentList '/k', $cmd
        Write-Output "Opened new cmd window: $cmd"
    } else {
        Write-Output $cmd
    }
}

function Pick-Session($CodexHome) {
    $sessions = @(Get-SessionObjects $CodexHome -DefaultAll)
    if ($sessions.Count -eq 0) {
        Write-Output 'No Codex sessions found for the selected range.'
        return
    }

    Write-Output ''
    Write-Output 'Codex sessions:'
    New-SessionTableRows $sessions | Format-Table No, Time, Workdir, Summary -AutoSize -Wrap

    Write-Output ''
    $choice = Read-Host 'Select a number; press Enter to cancel'
    if (-not $choice) { Write-Output 'Canceled.'; return }

    $number = 0
    if (-not [int]::TryParse($choice, [ref]$number)) {
        throw 'Please select by number from the table.'
    }
    if ($number -lt 1 -or $number -gt $sessions.Count) {
        throw "Selection out of range: $choice"
    }

    $selectedId = $sessions[$number - 1].id
    if ($NoOpen) {
        Write-Output "codex.cmd resume $selectedId"
    } else {
        Resume-Session $selectedId -OpenWindow
    }
}

$codexHome = Get-CodexHome
switch ($Mode) {
    'list' { List-Sessions $codexHome }
    'summarize' {
        if (-not $Id) { throw 'Mode summarize requires -Id.' }
        Summarize-Session $codexHome $Id
    }
    'show' {
        if (-not $Id) { throw 'Mode show requires -Id.' }
        Show-Session $codexHome $Id
    }
    'resume' { Resume-Session $Id -OpenWindow:$NewWindow }
    'pick' { Pick-Session $codexHome }
}
