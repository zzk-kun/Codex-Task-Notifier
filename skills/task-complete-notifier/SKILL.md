---
name: task-complete-notifier
description: Send task-complete notifications to a user's phone, Apple Watch, generic webhook, or WeCom group robot through local PowerShell scripts using ntfy, Pushover, Pushcut, generic JSON webhooks, or WeCom. Use when the user asks Codex to install, configure, test, or run project-completion notifications, Apple Watch alerts, webhook alerts, WeCom or 企业微信机器人 alerts, AGENTS.md notification rules, or end-of-task reminders.
---

# Task Complete Notifier

## Overview

Use this skill to set up and send local task-completion notifications. Prefer ntfy when the user wants a free phone and Apple Watch option. Use Pushover when the user already has a license. Use `wecom` for WeCom / 企业微信群机器人. Use `webhook` for a generic JSON endpoint.

The bundled scripts live in `scripts/` relative to this `SKILL.md`:

- `scripts/notify-task-complete.ps1`: sends a notification.
- `scripts/setup.ps1`: creates a local `.env` file.

Supported providers:

- `ntfy`: requires `NTFY_TOPIC`; `NTFY_SERVER` defaults to `https://ntfy.sh`, and `NTFY_TOKEN` is optional.
- `pushover`: requires `PUSHOVER_APP_TOKEN` and `PUSHOVER_USER_KEY`.
- `pushcut`: requires `PUSHCUT_WEBHOOK_URL`.
- `webhook`: requires `WEBHOOK_URL`, posts `{ "title": "...", "message": "..." }` as JSON.
- `wecom`: requires `WECOM_WEBHOOK_URL`, posts a WeCom markdown message.

## Safety Rules

- Never ask the user to paste an ntfy topic or token, Pushover, Pushcut, WeCom, or webhook secrets into chat.
- Public ntfy.sh topics are not access-controlled. Generate an unguessable topic, treat it like a secret, and do not put sensitive content in notifications.
- Never print, summarize, upload, or commit `.env` contents. The local setup script may display its newly generated ntfy topic once; do not repeat that value in chat or tool output.
- Keep `.env` local and ensure `.gitignore` includes it when copying scripts into a repo.
- Ask for network approval before sending a real notification if the tool environment requires escalation.
- Send completion notifications only when a project task is genuinely complete, not for ordinary chat, progress updates, or blocked work.
- Do not present personal WeChat group bots as an official default provider. Prefer WeCom group robots for WeChat-family webhook use cases.

## Setup Workflow

1. Choose a local destination for the notifier files.
2. Copy `scripts/notify-task-complete.ps1` and `scripts/setup.ps1` into that destination.
3. Add or update `.gitignore` near the destination so `.env` is ignored.
4. Choose provider with the user: `ntfy`, `pushover`, `pushcut`, `webhook`, or `wecom`.
5. Tell the user to run setup from PowerShell:

```powershell
.\setup.ps1 -Provider ntfy
```

Replace `ntfy` with the chosen provider when needed. For ntfy, subscribe to the generated topic in the iPhone app and do not expose that topic.

## Testing Workflow

First run a dry run; it must not require secrets or network:

```powershell
.\notify-task-complete.ps1 -Provider ntfy -Title "Task Notifier" -Message "Dry run OK" -DryRun
```

Then, after the user confirms `.env` is configured, send a real test:

```powershell
.\notify-task-complete.ps1 -Provider ntfy -Title "Task Notifier" -Message "Test notification"
```

## AGENTS.md Persistence

Installing the skill does not automatically edit `AGENTS.md`. When the user asks to make notifications persistent:

1. Ask whether they want the rule in the current project's `AGENTS.md` or their global Codex instructions.
2. Before editing, state the target file and the exact rule being added.
3. Add this rule, adapted only for the chosen script path and provider:

```markdown
- When a project task is genuinely complete and before the final response, run the local task-complete notifier script to send a completion notification. Do not send notifications for ordinary chat, intermediate progress, or blocked work. Never print, summarize, upload, or commit notifier `.env` secrets.
```

4. If no AGENTS file exists at the chosen project target, create it only after the user confirms.
5. Do not overwrite unrelated AGENTS content.

## Task Completion Workflow

At the end of a project task, after validation and before the final response, send one notification:

```powershell
.\notify-task-complete.ps1 -Provider ntfy -Title "Codex" -Message "Task completed"
```

Use the configured provider. If sending fails, mention the failure briefly in the final response and include the error category without exposing secrets.

## Troubleshooting

- `Missing required environment variable`: `.env` is missing or incomplete. Ask the user to run `setup.ps1` again for the chosen provider.
- `scripts are disabled`: tell the user to run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` in the current PowerShell window.
- WeCom did not receive the message: verify that the group robot webhook URL is current and that the group robot has not been removed.
- No Apple Watch alert: verify the phone alert first, then check iPhone Watch app notification mirroring for ntfy or Pushover.
