<p align="center">
  <h1 align="center">Task Complete Notifier</h1>
  <p align="center">Send a completion alert when Codex, a script, a build, or any long-running task finishes.</p>
</p>

<p align="center">
  <a href="README.zh-CN.md">中文说明</a>
  ·
  <a href="skills/task-complete-notifier">Codex Skill</a>
  ·
  <a href="#manual-setup">Manual setup</a>
</p>

<p align="center">
  <img alt="PowerShell" src="https://img.shields.io/badge/PowerShell-5%2B-4479A1">
  <img alt="Codex Skill" src="https://img.shields.io/badge/Codex-Skill-111827">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="Secrets" src="https://img.shields.io/badge/secrets-local_only-orange">
</p>

---

## What it does

Task Complete Notifier is a small Windows PowerShell utility for sending task-completion alerts to your phone, Apple Watch, team chat, or any webhook endpoint.

It is designed for cases where you do not want to keep watching the terminal: Codex work, test suites, builds, backups, local scripts, and other slow jobs.

## Supported providers

| Provider | Best for | Command value |
| --- | --- | --- |
| ntfy | Free iPhone and Apple Watch alerts | `ntfy` |
| Pushover | Phone and Apple Watch alerts | `pushover` |
| Pushcut | iOS automation webhooks | `pushcut` |
| Generic webhook | Any JSON endpoint | `webhook` |
| WeCom group robot | 企业微信群机器人 | `wecom` |

The generic webhook sends:

```json
{ "title": "Task Notifier", "message": "Task completed" }
```

The WeCom provider sends a markdown message to a WeCom group robot webhook.

## Fastest path: install as a Codex skill

Copy this into Codex:

```text
Install the Codex skill from https://github.com/zzk-kun/Codex-Task-Notifier/tree/main/skills/task-complete-notifier
```

Restart Codex after installation, then ask:

```text
Use $task-complete-notifier to set up task completion notifications.
```

Codex will walk through the local setup for ntfy, Pushover, Pushcut, generic webhook, or WeCom.

## Does it edit AGENTS.md automatically?

No. Installing the skill only installs the skill files.

If you want Codex to remember the notification rule for future tasks, ask:

```text
Use $task-complete-notifier to configure notifications and add the task-completion notification rule to my AGENTS.md.
```

Codex should ask whether to write the rule globally or only for the current project before editing any AGENTS file.

## Manual setup

Download this repository, open PowerShell in the project folder, then choose a provider.

### ntfy (recommended free option)

Install the free ntfy iPhone app, then run:

```powershell
.\setup.ps1 -Provider ntfy
.\notify-task-complete.ps1 -Provider ntfy -Title "Task Notifier" -Message "Test notification"
```

Setup generates an unguessable random topic and prints it once. Subscribe to that exact topic in the ntfy app. The free hosted service currently allows 250 messages per day. Topic names on the public `ntfy.sh` service are not access-controlled, so treat the generated topic like a password and do not send sensitive content in notifications.

### Pushover

```powershell
.\setup.ps1 -Provider pushover
.\notify-task-complete.ps1 -Provider pushover -Title "Task Notifier" -Message "Test notification"
```

### Generic webhook

```powershell
.\setup.ps1 -Provider webhook
.\notify-task-complete.ps1 -Provider webhook -Title "Task Notifier" -Message "Task completed"
```

### WeCom group robot

```powershell
.\setup.ps1 -Provider wecom
.\notify-task-complete.ps1 -Provider wecom -Title "Task Notifier" -Message "Task completed"
```

### Dry run

Dry run works for every provider and does not send a real request:

```powershell
.\notify-task-complete.ps1 -Provider wecom -Title "Task Notifier" -Message "Dry run OK" -DryRun
```

## WeChat and WeCom

WeCom group robots support incoming webhook URLs and fit this project well.

Regular personal WeChat groups do not provide the same official simple webhook flow, so this project does not treat personal WeChat bots as a default provider.

## Apple Watch

Apple Watch receives the alert by mirroring ntfy or Pushover notifications from your iPhone. If the phone receives the alert but the watch does not, check notification mirroring for the selected app in the iPhone Watch app.

## Project structure

```text
.
├── notify-task-complete.ps1
├── setup.ps1
├── .env.example
├── tests/test-notifier.ps1
└── skills/
    └── task-complete-notifier/
        ├── SKILL.md
        ├── agents/openai.yaml
        └── scripts/
```

## Security

- Do not paste ntfy topics or tokens, webhook URLs, Pushover keys, or Pushcut URLs into chat.
- `.env` stays on your machine and is ignored by Git.
- The notification script does not print secret values. Setup displays a newly generated ntfy topic once so you can subscribe; do not copy it into chat or logs.
