param(
  [ValidateSet("ntfy", "pushover", "pushcut", "webhook", "wecom")]
  [string]$Provider = "ntfy",

  [string]$Title = "Task Notifier",
  [string]$Message = "Task completed",
  [string]$Priority = "0",
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"

function Import-DotEnv {
  param([string]$Path)

  if (-not (Test-Path -LiteralPath $Path)) {
    return
  }

  Get-Content -LiteralPath $Path | ForEach-Object {
    $line = $_.Trim()
    if ($line.Length -eq 0 -or $line.StartsWith("#")) {
      return
    }

    $parts = $line -split "=", 2
    if ($parts.Count -ne 2) {
      return
    }

    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($value.StartsWith('"') -and $value.EndsWith('"')) {
      $value = $value.Substring(1, $value.Length - 2)
    }

    [Environment]::SetEnvironmentVariable($name, $value, "Process")
  }
}

function Require-Env {
  param([string]$Name)

  $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  if ([string]::IsNullOrWhiteSpace($value)) {
    throw "Missing required environment variable: $Name. Run .\setup.ps1 or copy .env.example to .env."
  }
  return $value
}

function Invoke-JsonWebhook {
  param(
    [string]$Uri,
    [object]$Payload
  )

  $json = $Payload | ConvertTo-Json -Depth 8 -Compress
  Invoke-RestMethod `
    -Uri $Uri `
    -Method Post `
    -Body $json `
    -ContentType "application/json" `
    -TimeoutSec 20 | Out-Null
}

Import-DotEnv -Path $envFile

if ($Provider -eq "ntfy") {
  if ($DryRun) {
    Write-Host "Dry run: would send ntfy notification."
    Write-Host "Title: $Title"
    Write-Host "Message: $Message"
    exit 0
  }

  $topic = Require-Env -Name "NTFY_TOPIC"
  $server = [Environment]::GetEnvironmentVariable("NTFY_SERVER", "Process")
  if ([string]::IsNullOrWhiteSpace($server)) {
    $server = "https://ntfy.sh"
  }

  $priorityMap = @{
    "-2" = 1
    "-1" = 2
    "0" = 3
    "1" = 4
    "2" = 5
    "min" = 1
    "low" = 2
    "default" = 3
    "high" = 4
    "max" = 5
    "urgent" = 5
    "3" = 3
    "4" = 4
    "5" = 5
  }
  $priorityKey = $Priority.ToLowerInvariant()
  if (-not $priorityMap.ContainsKey($priorityKey)) {
    throw "Invalid ntfy priority: $Priority. Use -2 to 5, or min, low, default, high, max, or urgent."
  }
  $ntfyPriority = $priorityMap[$priorityKey]
  $headers = @{}

  $token = [Environment]::GetEnvironmentVariable("NTFY_TOKEN", "Process")
  if (-not [string]::IsNullOrWhiteSpace($token)) {
    $headers.Authorization = "Bearer $token"
  }

  $payload = @{
    topic = $topic
    title = $Title
    message = $Message
    priority = $ntfyPriority
    tags = @("white_check_mark")
  } | ConvertTo-Json -Depth 4 -Compress

  Invoke-RestMethod `
    -Uri $server.TrimEnd('/') `
    -Method Post `
    -Headers $headers `
    -Body $payload `
    -ContentType "application/json; charset=utf-8" `
    -TimeoutSec 20 | Out-Null

  Write-Host "ntfy notification sent."
  exit 0
}

if ($Provider -eq "pushover") {
  if ($DryRun) {
    Write-Host "Dry run: would send Pushover notification."
    Write-Host "Title: $Title"
    Write-Host "Message: $Message"
    exit 0
  }

  $token = Require-Env -Name "PUSHOVER_APP_TOKEN"
  $user = Require-Env -Name "PUSHOVER_USER_KEY"

  $body = @{
    token = $token
    user = $user
    title = $Title
    message = $Message
    priority = $Priority
  }

  Invoke-RestMethod `
    -Uri "https://api.pushover.net/1/messages.json" `
    -Method Post `
    -Body $body `
    -TimeoutSec 20 | Out-Null

  Write-Host "Pushover notification sent."
  exit 0
}

if ($Provider -eq "pushcut") {
  if ($DryRun) {
    Write-Host "Dry run: would send Pushcut webhook."
    Write-Host "Title: $Title"
    Write-Host "Message: $Message"
    exit 0
  }

  $webhookUrl = Require-Env -Name "PUSHCUT_WEBHOOK_URL"
  Invoke-JsonWebhook -Uri $webhookUrl -Payload @{ title = $Title; text = $Message }

  Write-Host "Pushcut notification sent."
  exit 0
}

if ($Provider -eq "webhook") {
  if ($DryRun) {
    Write-Host "Dry run: would send generic webhook."
    Write-Host "Title: $Title"
    Write-Host "Message: $Message"
    exit 0
  }

  $webhookUrl = Require-Env -Name "WEBHOOK_URL"
  Invoke-JsonWebhook -Uri $webhookUrl -Payload @{ title = $Title; message = $Message }

  Write-Host "Generic webhook notification sent."
  exit 0
}

if ($Provider -eq "wecom") {
  if ($DryRun) {
    Write-Host "Dry run: would send WeCom group robot webhook."
    Write-Host "Title: $Title"
    Write-Host "Message: $Message"
    exit 0
  }

  $webhookUrl = Require-Env -Name "WECOM_WEBHOOK_URL"
  $content = "**$Title**`n`n$Message"
  Invoke-JsonWebhook -Uri $webhookUrl -Payload @{ msgtype = "markdown"; markdown = @{ content = $content } }

  Write-Host "WeCom webhook notification sent."
  exit 0
}
