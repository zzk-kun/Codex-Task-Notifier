$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$notifyScript = Join-Path $repoRoot "notify-task-complete.ps1"
$setupScript = Join-Path $repoRoot "setup.ps1"
$skillNotifyScript = Join-Path $repoRoot "skills\task-complete-notifier\scripts\notify-task-complete.ps1"
$skillSetupScript = Join-Path $repoRoot "skills\task-complete-notifier\scripts\setup.ps1"

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) {
    throw "Assertion failed: $Message"
  }
}

foreach ($path in @($notifyScript, $setupScript, $skillNotifyScript, $skillSetupScript)) {
  $tokens = $null
  $errors = $null
  [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
  Assert-True ($errors.Count -eq 0) "PowerShell syntax errors in $path"
}

Assert-True ((Get-FileHash $notifyScript).Hash -eq (Get-FileHash $skillNotifyScript).Hash) "notifier script copies differ"
Assert-True ((Get-FileHash $setupScript).Hash -eq (Get-FileHash $skillSetupScript).Hash) "setup script copies differ"

$defaultOutput = & $notifyScript -Title "Codex" -Message "完成任务" -DryRun *>&1 | Out-String
Assert-True ($defaultOutput -match "ntfy") "ntfy is not the default provider"

foreach ($provider in @("ntfy", "pushover", "pushcut", "webhook", "wecom")) {
  $output = & $notifyScript -Provider $provider -Title "Codex" -Message "Dry run" -DryRun *>&1 | Out-String
  Assert-True ($output -match "Dry run") "dry run failed for $provider"
}

$previousTopic = [Environment]::GetEnvironmentVariable("NTFY_TOPIC", "Process")
[Environment]::SetEnvironmentVariable("NTFY_TOPIC", "test-topic", "Process")
$invalidPriorityRejected = $false
try {
  & $notifyScript -Provider ntfy -Priority "invalid" *>&1 | Out-Null
} catch {
  $invalidPriorityRejected = $_.Exception.Message -match "Invalid ntfy priority"
} finally {
  [Environment]::SetEnvironmentVariable("NTFY_TOPIC", $previousTopic, "Process")
}
Assert-True $invalidPriorityRejected "invalid ntfy priority was not rejected before sending"

$tempDir = Join-Path ([IO.Path]::GetTempPath()) ("task-notifier-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $tempDir | Out-Null
try {
  Copy-Item -LiteralPath $setupScript -Destination (Join-Path $tempDir "setup.ps1")
  @(
    "# Existing provider settings"
    "PUSHOVER_APP_TOKEN=test-app-token"
    "PUSHOVER_USER_KEY=test-user-key"
  ) | Set-Content -LiteralPath (Join-Path $tempDir ".env") -Encoding UTF8
  & (Join-Path $tempDir "setup.ps1") -Provider ntfy -Force *>&1 | Out-Null
  $envText = Get-Content -LiteralPath (Join-Path $tempDir ".env") -Raw
  Assert-True ($envText -match "(?m)^PUSHOVER_APP_TOKEN=test-app-token\r?$") "existing provider settings were not preserved"
  Assert-True ($envText -match "(?m)^NTFY_SERVER=https://ntfy\.sh\r?$") "ntfy server was not configured"
  Assert-True ($envText -match "(?m)^NTFY_TOPIC=codex-[0-9a-f]{32}\r?$") "a strong random ntfy topic was not generated"
} finally {
  Remove-Item -LiteralPath $tempDir -Recurse -Force
}

Write-Host "All notifier tests passed."
