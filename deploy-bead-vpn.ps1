param(
  [Parameter(Mandatory=$true)]
  [string]$ServerIp,

  [Parameter(Mandatory=$true)]
  [string]$Domain,

  [string]$SshUser = "root",
  [string]$PanelUser = "admin",

  [Parameter(Mandatory=$true)]
  [string]$PanelPass,

  [ValidateSet("y","n")]
  [string]$IssueSsl = "y",

  [string]$Email = "",
  [string]$KeyPath = ""
)

$ErrorActionPreference = "Stop"
$LocalDir = Join-Path $PSScriptRoot "bead-vpn-install"

if (-not (Test-Path $LocalDir)) {
  throw "Missing folder: $LocalDir"
}

function Quote-Sh([string]$Value) {
  $escaped = $Value.Replace("'", "'\''")
  return "'$escaped'"
}

$sshArgs = @("-o", "StrictHostKeyChecking=no")
if ($KeyPath) {
  $sshArgs = @("-i", $KeyPath) + $sshArgs
}

$target = "${SshUser}@${ServerIp}"
$remoteDir = "/root/bead-vpn-install"

Write-Host "Uploading BEAD VPN installer to $target ..." -ForegroundColor Cyan
& scp @sshArgs -r $LocalDir "${target}:/root/"
if ($LASTEXITCODE -ne 0) { throw "scp failed" }

$remoteCmd = @(
  "cd $(Quote-Sh $remoteDir)",
  "chmod +x *.sh",
  "DOMAIN=$(Quote-Sh $Domain) ADMIN_USER=$(Quote-Sh $PanelUser) ADMIN_PASS=$(Quote-Sh $PanelPass) USE_SSL=$(Quote-Sh $IssueSsl) EMAIL=$(Quote-Sh $Email) NONINTERACTIVE=1 ./install-bead-vpn-panel.sh"
) -join " && "

Write-Host "Running installer on $target ..." -ForegroundColor Cyan
& ssh @sshArgs $target $remoteCmd
if ($LASTEXITCODE -ne 0) { throw "remote install failed" }

Write-Host ""
Write-Host "Done: https://$Domain/" -ForegroundColor Green
