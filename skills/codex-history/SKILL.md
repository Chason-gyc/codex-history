---
name: codex-history
description: Find, inspect, summarize, and resume local Codex CLI conversation sessions stored under the user's CODEX_HOME or ~/.codex directory. Use when the user asks to see yesterday's/recent Codex chat IDs, summarize a session by ID, recover prior conversation context, display saved chat content, locate Codex history files, open/resume a previous Codex session in a new terminal, or uses command-like prompts such as /historySession, historySession, history session, 会话历史, 历史会话, 查看历史对话, or 切换到历史会话.
---

# Codex History

## Overview

Use this skill to work with local Codex CLI session history. The usual storage root is `$env:CODEX_HOME` when set, otherwise `$HOME/.codex` on Unix or `%USERPROFILE%\.codex` on Windows.

Bundled helper: `scripts/codex-history.ps1` extracts session IDs, timestamps, workdirs, user/assistant messages, and resume commands from local `.jsonl` records. `scripts/codex-history.cmd` is the friendly command wrapper; `chistory.cmd` and `historySession.cmd` are aliases.

## Trigger Pattern

Treat `/historySession` as a command-like prompt, not as a built-in Codex TUI slash command. When the user enters `/historySession`, run the history workflow:

1. List recent sessions unless a date or ID is included.
2. If the user asks to enter/switch/open, use the picker or resume mode.
3. If the user selects an ID, open it with `codex.cmd resume <SESSION_ID>` in a new cmd window when requested.

Example prompt handling:

```text
/historySession
/historySession yesterday
/historySession <session-id>
/historySession 打开昨天第 2 个会话
```

## Quick Commands

After installation, use:

```cmd
codex-history
chistory
historySession
```

Common operations:

```cmd
codex-history
codex-history yesterday
codex-history list all 20
codex-history show <session-id>
codex-history summary <session-id>
codex-history resume <session-id>
```

Direct helper usage:

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.codex\skills\codex-history\scripts\codex-history.ps1" -Mode list -All -Limit 20
```

## Workflow

1. Resolve the Codex home directory. Prefer `$env:CODEX_HOME`; otherwise use `%USERPROFILE%\.codex` on Windows.
2. For date requests, treat relative days in the user's current local timezone. `yesterday` means local yesterday, not UTC yesterday.
3. Use `Mode list` to find candidate sessions. Prefer session files under `sessions/` and use `session_index.jsonl` only as supplemental metadata because it may be stale.
4. Use `Mode pick -All -Limit 20` when the user wants an interactive list and direct entry. It prompts for a number, then opens a new cmd window by default.
5. Use `Mode summarize` for each selected ID. It prints metadata, user prompts, assistant final messages, and tool-call names while filtering system/developer/environment noise.
6. Write a concise natural-language summary yourself from the extracted material. Include the session ID, workdir, topic, key outcome, and any unresolved verification/test status.
7. To actually continue an old session, use `codex.cmd resume <SESSION_ID>` on Windows PowerShell/cmd. If the user asks you to open it, use `Mode resume -NewWindow`; visible windows require user approval when sandbox rules require it.

## Output Guidance

For a list of prior sessions, return a compact table with `序号`, `时间`, `工作目录`, and `会话简称`. Hide session IDs unless the user explicitly asks for IDs.

For summaries, avoid dumping the full transcript unless the user asks. Summarize:

- user goal
- important analysis/findings
- files created or edited
- commands/tests attempted
- final status and follow-up point

## Caveats

- Session files may contain sensitive prompts, tool outputs, and paths. Read only the IDs/dates requested unless the user asks for broader history.
- Raw `.jsonl` includes system instructions and tool logs. Filter to user/assistant messages and relevant tool calls before answering.
- Some old records may display mojibake if written or printed with the wrong console encoding. Set `[Console]::OutputEncoding = [Text.Encoding]::UTF8` before reading on Windows.
- Current Codex cannot transform the active conversation into another session in-place. Resuming a session is a CLI operation: `codex.cmd resume <SESSION_ID>`.
- The recommended global command is `codex-history`; `chistory` is a short alias and `historySession` is kept for compatibility.

