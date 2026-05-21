param(
  [string]$HostName = "brisen",
  [string]$UserName = "appsmithsvc",
  [string]$RemoteAppDir = "/srv/mediawiki/current",
  [string]$RemoteTmpDir = "/tmp/trigowiki-deploy",
  [string]$RemoteCommand = "up -d --build",
  [switch]$SetupKey,
  [switch]$SkipRun
)

$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command '$Name' wurde nicht gefunden. Bitte OpenSSH Client installieren."
  }
}

function Set-SshKeyAuth {
  $sshDir = Join-Path $env:USERPROFILE ".ssh"
  $privateKey = Join-Path $sshDir "id_ed25519"
  $publicKey = "$privateKey.pub"

  if (-not (Test-Path $privateKey)) {
    Write-Host "Erzeuge SSH Key (ed25519)..."
    ssh-keygen -t ed25519 -C "$UserName@$HostName" -f $privateKey
  }

  if (-not (Test-Path $publicKey)) {
    throw "Public key nicht gefunden: $publicKey"
  }

  Write-Host "Installiere Public Key auf $UserName@$HostName ..."
  Get-Content $publicKey | ssh "$UserName@$HostName" "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"

  Write-Host "Teste SSH Login..."
  ssh "$UserName@$HostName" "hostname"
}

function Copy-RemoteItem {
  param(
    [string]$LocalPath,
    [string]$RemotePath
  )

  if (Test-Path $LocalPath) {
    $copyTarget = "{0}@{1}:{2}" -f $UserName, $HostName, $RemotePath
    Write-Host "Kopiere $LocalPath nach $copyTarget ..."
    scp -r $LocalPath $copyTarget
  }
}

Test-CommandAvailable -Name "ssh"
Test-CommandAvailable -Name "scp"

if ($SetupKey) {
  Set-SshKeyAuth
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$remotePrepare = "rm -rf $RemoteTmpDir; mkdir -p $RemoteTmpDir $RemoteAppDir"
ssh "$UserName@$HostName" $remotePrepare

Copy-RemoteItem -LocalPath "docker-compose.yml" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "Dockerfile" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "docker-entrypoint.sh" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "run-elasticsearch.sh" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "config" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "script" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "mediawiki" -RemotePath "$RemoteTmpDir/"

$skipRunValue = if ($SkipRun.IsPresent) { "True" } else { "False" }
$remoteCommands = @(
  "mkdir -p $RemoteAppDir",
  "cp -a $RemoteTmpDir/. $RemoteAppDir/",
  "find $RemoteAppDir -name '*.sh' -type f -exec chmod 750 {} +",
  "rm -rf $RemoteTmpDir",
  "if [ '$skipRunValue' = 'True' ]; then exit 0; fi",
  "cd $RemoteAppDir",
  "docker compose $RemoteCommand",
  "docker ps --filter name=mediawiki --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'"
) -join "; "

Write-Host "Führe Remote-Befehle auf $HostName aus..."
ssh -tt "$UserName@$HostName" "$remoteCommands"

Write-Host "Fertig."
