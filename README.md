# Codex History

A local session picker for Codex CLI. List previous Codex sessions, inspect summaries, and resume a session from your terminal.

## Features

- Lists local Codex CLI sessions from `~/.codex/sessions`
- Shows a compact table with sequence number, time, working directory, and first prompt
- Resumes a selected session with `codex.cmd resume <session-id>`
- Includes a Codex skill so future Codex conversations can understand history-session requests
- Installs friendly commands: `codex-history`, `chistory`, and `historySession`

## Install

Windows PowerShell:

```powershell
git clone https://github.com/Chason-gyc/codex-history.git
cd codex-history
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Open a new terminal after installation.

## Usage

Interactive picker:

```cmd
chistory
```

Other commands:

```cmd
codex-history
codex-history yesterday
codex-history list all 20
codex-history show <session-id>
codex-history summary <session-id>
codex-history resume <session-id>
```

Aliases:

```cmd
chistory
historySession
```

## How It Works

Codex CLI stores local sessions under:

```text
%USERPROFILE%\.codex\sessions
```

This tool reads those `.jsonl` files, extracts useful metadata and chat messages, and calls:

```cmd
codex.cmd resume <session-id>
```

The session ID is hidden in the interactive table by default. Selecting a number maps back to the underlying session ID.

## Installed Files

The installer copies the skill to:

```text
%USERPROFILE%\.codex\skills\codex-history
```

It installs command shims to:

```text
%APPDATA%\npm
```

`%APPDATA%\npm` is added to the user `PATH` if it is missing.

## Privacy

Codex sessions may contain prompts, tool outputs, file paths, and code snippets. This tool only reads local files on your machine. Do not publish your `~/.codex/sessions` directory.

