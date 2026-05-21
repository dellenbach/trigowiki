param(
  [string]$HostName = "brisen",
  [string]$UserName = "trigowikisvc",
  [string]$RemoteRepoDir = "/tmp/trigowiki-staging-repo-$UserName",
  [string]$StagingRoot = "/srv/mediawiki-staging",
  [int]$StagingHttpPort = 8081,
  [string]$StagingMediaWikiServer = "http://brisen:8081",
  [Parameter(Mandatory = $true)]
  [System.Security.SecureString]$StagingDbRootValue,
  [Parameter(Mandatory = $true)]
  [System.Security.SecureString]$StagingMediaWikiPrivateValue,
  [switch]$SkipVolumeReset,
  [switch]$SkipReindex,
  [switch]$SkipImageBuild
)

$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
  param([string]$Name)
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command '$Name' wurde nicht gefunden. Bitte OpenSSH Client installieren."
  }
}

function Invoke-ExternalCommand {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList,
    [string]$InputText
  )

  if ($PSBoundParameters.ContainsKey('InputText')) {
    $InputText | & $FilePath @ArgumentList
  } else {
    & $FilePath @ArgumentList
  }

  if ($LASTEXITCODE -ne 0) {
    throw "Command '$FilePath $($ArgumentList -join ' ')' ist mit Exitcode $LASTEXITCODE fehlgeschlagen."
  }
}

function Copy-RemoteItem {
  param(
    [string]$LocalPath,
    [string]$RemotePath
  )

  if (Test-Path $LocalPath) {
    $copyTarget = "${UserName}@${HostName}:$RemotePath"
    Write-Host "Kopiere $LocalPath nach $copyTarget ..."
    Invoke-ExternalCommand -FilePath "scp" -ArgumentList @("-r", $LocalPath, $copyTarget)
  }
}

function ConvertTo-PlainText {
  param([System.Security.SecureString]$Value)

  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($Value)
  try {
    [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
}

Test-CommandAvailable -Name "ssh"
Test-CommandAvailable -Name "scp"

$repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $repoRoot

$target = "${UserName}@${HostName}"
$remoteRunner = "/tmp/trigowiki-run-staging-refresh-$UserName.sh"
$resetVolumes = if ($SkipVolumeReset.IsPresent) { "0" } else { "1" }
$runReindex = if ($SkipReindex.IsPresent) { "0" } else { "1" }
$buildImage = if ($SkipImageBuild.IsPresent) { "0" } else { "1" }
$stagingDbRootPlainText = ConvertTo-PlainText -Value $StagingDbRootValue
$stagingMediaWikiSecretPlainText = ConvertTo-PlainText -Value $StagingMediaWikiPrivateValue

Invoke-ExternalCommand -FilePath "ssh" -ArgumentList @($target, "rm -rf '$RemoteRepoDir'; mkdir -p '$RemoteRepoDir'")

Copy-RemoteItem -LocalPath "config" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "script" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "docs" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "Ressourcen" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "Dockerfile" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "docker-entrypoint.sh" -RemotePath "$RemoteRepoDir/"
Copy-RemoteItem -LocalPath "docker-compose.staging.yml" -RemotePath "$RemoteRepoDir/"

$remoteScript = @'
#!/bin/bash
set -euo pipefail

cd "$1"
chmod +x script/staging-refresh.sh

export STAGING_ROOT="$2"
export STAGING_HTTP_PORT="$3"
export STAGING_MEDIAWIKI_SERVER="$4"
export STAGING_DB_ROOT_PASSWORD="$5"
export STAGING_MEDIAWIKI_SECRET_KEY="$6"
export RESET_STAGING_VOLUMES="$7"
export RUN_STAGING_REINDEX="$8"
export BUILD_STAGING_IMAGE="$9"

./script/staging-refresh.sh
'@

$remoteScript = $remoteScript -replace "`r`n", "`n"
Invoke-ExternalCommand -FilePath "ssh" -ArgumentList @($target, "tr -d '\015' > '$remoteRunner'; chmod 700 '$remoteRunner'") -InputText $remoteScript

Write-Host "Fuehre Staging-Refresh auf $target aus..."
Invoke-ExternalCommand -FilePath "ssh" -ArgumentList @($target, "'$remoteRunner' '$RemoteRepoDir' '$StagingRoot' '$StagingHttpPort' '$StagingMediaWikiServer' '$stagingDbRootPlainText' '$stagingMediaWikiSecretPlainText' '$resetVolumes' '$runReindex' '$buildImage'")

Write-Host "Fertig: $StagingMediaWikiServer"
