param(
  [ValidateSet("ntfy", "pushover", "pushcut", "webhook", "wecom")]
  [string]$Provider = "ntfy",
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile = Join-Path $scriptDir ".env"

function ConvertFrom-SecureStringPlainText {
  param([Security.SecureString]$SecureValue)

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

function Read-SecretText {
  param([string]$Prompt)
  $secure = Read-Host $Prompt -AsSecureString
  return ConvertFrom-SecureStringPlainText -SecureValue $secure
}

function Set-DotEnvValues {
  param(
    [string]$Path,
    [Collections.IDictionary]$Values
  )

  $lines = @()
  if (Test-Path -LiteralPath $Path) {
    $lines = @(Get-Content -LiteralPath $Path)
  }

  $selectedKeysExist = $false
  foreach ($line in $lines) {
    $parts = $line -split "=", 2
    if ($parts.Count -eq 2 -and $Values.Contains($parts[0].Trim())) {
      $selectedKeysExist = $true
      break
    }
  }

  if ($selectedKeysExist -and -not $Force) {
    $overwrite = Read-Host "Configuration for $Provider already exists. Replace only its values? Type YES to continue"
    if ($overwrite -ne "YES") {
      Write-Host "Setup cancelled."
      return $false
    }
  }

  $written = @{}
  $updatedLines = @(
    foreach ($line in $lines) {
      $parts = $line -split "=", 2
      $name = if ($parts.Count -eq 2) { $parts[0].Trim() } else { "" }
      if ($Values.Contains($name)) {
        "$name=$($Values[$name])"
        $written[$name] = $true
      } else {
        $line
      }
    }
  )

  if ($updatedLines.Count -eq 0) {
    $updatedLines += "# Local configuration. Do not commit this file."
  } elseif (-not [string]::IsNullOrWhiteSpace($updatedLines[-1])) {
    $updatedLines += ""
  }

  foreach ($name in $Values.Keys) {
    if (-not $written.ContainsKey($name)) {
      $updatedLines += "$name=$($Values[$name])"
    }
  }

  $updatedLines | Set-Content -LiteralPath $Path -Encoding UTF8
  return $true
}

if ($Provider -eq "ntfy") {
  Write-Host "ntfy setup"
  Write-Host "An unguessable random topic will be generated for the free ntfy.sh service."

  $bytes = New-Object byte[] 16
  $random = [Security.Cryptography.RandomNumberGenerator]::Create()
  try {
    $random.GetBytes($bytes)
  } finally {
    $random.Dispose()
  }
  $topicSuffix = -join ($bytes | ForEach-Object { $_.ToString("x2") })
  $topic = "codex-$topicSuffix"

  $values = [ordered]@{
    NTFY_SERVER = "https://ntfy.sh"
    NTFY_TOPIC = $topic
    NTFY_TOKEN = ""
  }
  if (-not (Set-DotEnvValues -Path $envFile -Values $values)) { exit 0 }

  Write-Host ".env configured for ntfy."
  Write-Host "Subscribe to this topic in the ntfy iPhone app: $topic"
  Write-Host "Do not share the topic publicly."
  exit 0
}

if ($Provider -eq "pushover") {
  Write-Host "Pushover setup"
  Write-Host "Paste values from pushover.net. Input is hidden where possible."

  $appToken = Read-SecretText -Prompt "PUSHOVER_APP_TOKEN"
  $userKey = Read-SecretText -Prompt "PUSHOVER_USER_KEY"

  $values = [ordered]@{
    PUSHOVER_APP_TOKEN = $appToken
    PUSHOVER_USER_KEY = $userKey
  }
  if (-not (Set-DotEnvValues -Path $envFile -Values $values)) { exit 0 }

  Write-Host ".env configured for Pushover."
  exit 0
}

if ($Provider -eq "pushcut") {
  Write-Host "Pushcut setup"
  $webhookUrl = Read-SecretText -Prompt "PUSHCUT_WEBHOOK_URL"

  $values = [ordered]@{ PUSHCUT_WEBHOOK_URL = $webhookUrl }
  if (-not (Set-DotEnvValues -Path $envFile -Values $values)) { exit 0 }

  Write-Host ".env configured for Pushcut."
  exit 0
}

if ($Provider -eq "webhook") {
  Write-Host "Generic webhook setup"
  $webhookUrl = Read-SecretText -Prompt "WEBHOOK_URL"

  $values = [ordered]@{ WEBHOOK_URL = $webhookUrl }
  if (-not (Set-DotEnvValues -Path $envFile -Values $values)) { exit 0 }

  Write-Host ".env configured for generic webhook."
  exit 0
}

if ($Provider -eq "wecom") {
  Write-Host "WeCom group robot setup"
  $webhookUrl = Read-SecretText -Prompt "WECOM_WEBHOOK_URL"

  $values = [ordered]@{ WECOM_WEBHOOK_URL = $webhookUrl }
  if (-not (Set-DotEnvValues -Path $envFile -Values $values)) { exit 0 }

  Write-Host ".env configured for WeCom."
  exit 0
}
