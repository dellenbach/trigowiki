param(
  [string]$HostName = "brisen",
  [string]$UserName = "trigowikisvc",
  [string]$RemoteRoot = "/srv/mediawiki-production",
  [string]$RemoteTmpDir = "/tmp/trigowiki-deploy",
  [switch]$SetupKey,
  [switch]$SkipRun
)

# Kopiert config/mediawiki-lts/, script/ und Ressourcen/ auf den Server
# und startet den Wiki-Container bei Bedarf neu.
#
# Erstinstallation:  deploy-trigowiki.ps1 -SetupKey   (SSH-Key einrichten + deployen)
# Normales Deploy:   deploy-trigowiki.ps1
# Nur kopieren:      deploy-trigowiki.ps1 -SkipRun

$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command '$Name' nicht gefunden. OpenSSH Client installieren."
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
  Get-Content $publicKey | ssh "$UserName@$HostName" "umask 077; mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
  Write-Host "Teste SSH Login..."
  ssh "$UserName@$HostName" "hostname"
}

function Copy-Remote {
  param([string]$Local, [string]$Remote)
  if (Test-Path $Local) {
    $target = "${UserName}@${HostName}:$Remote"
    Write-Host "  $Local -> $target"
    scp -r $Local $target
  }
}

Test-CommandAvailable -Name "ssh"
Test-CommandAvailable -Name "scp"

if ($SetupKey) { Set-SshKeyAuth }

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

ssh "$UserName@$HostName" "rm -rf $RemoteTmpDir; mkdir -p $RemoteTmpDir"

Write-Host "Kopiere Dateien nach ${HostName}:${RemoteTmpDir} ..."
Copy-Remote -Local "docker-compose.yml"   -Remote "$RemoteTmpDir/"
Copy-Remote -Local ".env.example"         -Remote "$RemoteTmpDir/"
Copy-Remote -Local "config"               -Remote "$RemoteTmpDir/"
Copy-Remote -Local "script"               -Remote "$RemoteTmpDir/"
Copy-Remote -Local "Ressourcen"           -Remote "$RemoteTmpDir/"

$skipFlag = if ($SkipRun.IsPresent) { "1" } else { "0" }

$remoteCmd = @"
set -euo pipefail
PROD_ROOT="$RemoteRoot"
TMP="$RemoteTmpDir"

# Config und Scripts deployen
mkdir -p "\${PROD_ROOT}/config-lts" "\${PROD_ROOT}/script" "\${PROD_ROOT}/Ressourcen"
cp -af "\${TMP}/config/mediawiki-lts/." "\${PROD_ROOT}/config-lts/"
cp -af "\${TMP}/script/."              "\${PROD_ROOT}/script/"
cp -af "\${TMP}/Ressourcen/."          "\${PROD_ROOT}/Ressourcen/"
chmod -R a+rX "\${PROD_ROOT}/Ressourcen"
find "\${PROD_ROOT}/script" -name '*.sh' -exec chmod 750 {} +

# docker-compose.yml und .env.example im Repo-Verzeichnis ablegen
mkdir -p "\${PROD_ROOT}/repo"
cp -f "\${TMP}/docker-compose.yml" "\${PROD_ROOT}/repo/"
cp -f "\${TMP}/.env.example"       "\${PROD_ROOT}/repo/"

rm -rf "\${TMP}"

if [ "$skipFlag" = "1" ]; then
  echo "SkipRun gesetzt; kein Container-Restart."
  exit 0
fi

echo "Wiki-Container neu starten..."
bash "\${PROD_ROOT}/script/start-wiki-production.sh"
"@

Write-Host "Ausfuehren auf $HostName ..."
ssh -tt "$UserName@$HostName" "$remoteCmd"
Write-Host "Fertig."


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
Copy-RemoteItem -LocalPath "Ressourcen" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "script" -RemotePath "$RemoteTmpDir/"
Copy-RemoteItem -LocalPath "mediawiki" -RemotePath "$RemoteTmpDir/"

$skipRunValue = if ($SkipRun.IsPresent) { "True" } else { "False" }
$remoteCommands = @(
  "mkdir -p $RemoteAppDir",
  "cp -a $RemoteTmpDir/. $RemoteAppDir/",
  "if [ -d '$RemoteAppDir/config/mediawiki' ]; then mkdir -p '$RemoteHostConfigDir' '$RemoteProductionConfigDir'; cp -af '$RemoteAppDir/config/mediawiki/.' '$RemoteHostConfigDir/'; cp -af '$RemoteAppDir/config/mediawiki/.' '$RemoteProductionConfigDir/'; fi",
  "if [ -d '$RemoteAppDir/config/mediawiki-lts' ]; then mkdir -p '$RemoteProductionConfigLtsDir'; cp -af '$RemoteAppDir/config/mediawiki-lts/.' '$RemoteProductionConfigLtsDir/'; fi",
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
