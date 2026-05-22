param(
  [string]$HostName = "brisen",
  [string]$UserName = "trigowikisvc",
  [string]$RemoteRoot = "/srv/mediawiki-production",
  [string]$DbContainer = "mediawiki_mysql_production",
  [string]$WikiContainer = "mediawiki_wiki_production",
  [string]$SearchContainer = "opensearch_production",
  [string]$DbName = "wikidb",
  [string]$LocalBackupRoot = "\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\new-wiki",
  [string]$RemoteWorkDir = "/tmp/trigowiki-windows-backup",
  [switch]$SkipFileArchive,
  [switch]$KeepRemoteBundle
)

$ErrorActionPreference = "Stop"

function Test-CommandAvailable {
  param([string]$Name)

  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "Command '$Name' wurde nicht gefunden. Bitte den Windows OpenSSH Client installieren."
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

function Invoke-ExternalCommandWithOutput {
  param(
    [string]$FilePath,
    [string[]]$ArgumentList
  )

  $output = & $FilePath @ArgumentList 2>&1
  if ($LASTEXITCODE -ne 0) {
    $output | ForEach-Object { Write-Host $_ }
    throw "Command '$FilePath $($ArgumentList -join ' ')' ist mit Exitcode $LASTEXITCODE fehlgeschlagen."
  }

  $output
}

Test-CommandAvailable -Name "ssh"
Test-CommandAvailable -Name "scp"

$backupId = "trigowiki-new-{0}" -f (Get-Date).ToUniversalTime().ToString("yyyyMMddTHHmmssZ")
$target = "${UserName}@${HostName}"
$localBackupDir = Join-Path $LocalBackupRoot $backupId
$remoteRunner = "$RemoteWorkDir/run-backup-$backupId.sh"
$remoteBundle = "$RemoteWorkDir/$backupId.tgz"
$remoteChecksum = "$RemoteWorkDir/$backupId.tgz.sha256"
$archiveFiles = if ($SkipFileArchive.IsPresent) { "0" } else { "1" }

New-Item -ItemType Directory -Path $localBackupDir -Force | Out-Null

$remoteScript = @'
#!/bin/bash
set -euo pipefail

backup_id=$1
remote_root=$2
db_container=$3
wiki_container=$4
search_container=$5
db_name=$6
remote_work_dir=$7
archive_files=$8

snapshot_dir="${remote_work_dir}/${backup_id}"
bundle="${remote_work_dir}/${backup_id}.tgz"
checksum="${bundle}.sha256"

if ! docker inspect "${db_container}" >/dev/null 2>&1; then
    echo "DB container not found: ${db_container}" >&2
    exit 1
fi

if [ "${archive_files}" = "1" ] && [ ! -d "${remote_root}" ]; then
    echo "Remote root not found: ${remote_root}" >&2
    exit 1
fi

rm -rf "${snapshot_dir}" "${bundle}" "${checksum}"
mkdir -p "${snapshot_dir}"

echo "Creating ${snapshot_dir}"

{
    echo "backup_id=${backup_id}"
    echo "created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "host=$(hostname -f 2>/dev/null || hostname)"
    echo "remote_root=${remote_root}"
    echo "db_container=${db_container}"
    echo "wiki_container=${wiki_container}"
    echo "search_container=${search_container}"
    echo "db_name=${db_name}"
} > "${snapshot_dir}/metadata.env"

echo "Saving Docker inventory"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "${snapshot_dir}/docker-ps.txt"
docker volume ls > "${snapshot_dir}/docker-volumes.txt"

inspect_containers=()
for container_name in "${db_container}" "${wiki_container}" "${search_container}"; do
    if docker inspect "${container_name}" >/dev/null 2>&1; then
        inspect_containers+=("${container_name}")
    else
        echo "Container not found during inspect: ${container_name}" >> "${snapshot_dir}/warnings.txt"
    fi
done

if [ "${#inspect_containers[@]}" -gt 0 ]; then
    docker inspect "${inspect_containers[@]}" > "${snapshot_dir}/docker-inspect.json"
fi

echo "Dumping database ${db_name} from ${db_container}"
docker exec "${db_container}" sh -c "exec mysqldump -uroot -p\"\$MYSQL_ROOT_PASSWORD\" '${db_name}'" > "${snapshot_dir}/${db_name}.sql"

if [ "${archive_files}" = "1" ]; then
    echo "Archiving ${remote_root}"
    root_parent=$(dirname "${remote_root}")
    root_name=$(basename "${remote_root}")

    set +e
    tar \
        --exclude="${root_name}/backup/snapshots" \
        --exclude="${root_name}/backup/windows" \
        --exclude="${root_name}/backup/*.tgz" \
        -C "${root_parent}" \
        -czf "${snapshot_dir}/wiki-files.tgz" \
        "${root_name}"
    tar_status=$?
    set -e

    if [ "${tar_status}" -gt 1 ]; then
        echo "File archive failed with tar exit code ${tar_status}" >&2
        exit "${tar_status}"
    fi

    if [ "${tar_status}" -eq 1 ]; then
        echo "tar reported changed files while archiving the live wiki; archive was still written." >> "${snapshot_dir}/warnings.txt"
    fi
else
    echo "File archive skipped by caller" > "${snapshot_dir}/wiki-files-skipped.txt"
fi

cat > "${snapshot_dir}/RESTORE.md" <<EOF
# ${backup_id}

Inhalt:

- metadata.env: Backup-Metadaten
- docker-ps.txt: Containerstatus zum Backupzeitpunkt
- docker-inspect.json: Containerdetails, soweit die Container vorhanden waren
- docker-volumes.txt: Docker-Volume-Liste
- ${db_name}.sql: Datenbankdump aus ${db_container}
- wiki-files.tgz: Archiv von ${remote_root}, wenn nicht uebersprungen
- warnings.txt: Hinweise, falls beim Live-Backup Dateien geaendert wurden oder Container fehlten

Restore-Kurzablauf:

1. Zielcontainer stoppen.
2. Dateien aus wiki-files.tgz nach ${remote_root} wiederherstellen.
3. Datenbankvolume neu anlegen oder leeren.
4. ${db_name}.sql in die Datenbank ${db_name} importieren.
5. Suchindex danach neu aufbauen; Elasticsearch/OpenSearch-Daten sind nicht als Restore-Quelle gedacht.
EOF

find "${snapshot_dir}" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort > "${snapshot_dir}/MANIFEST.txt"

echo "Packing Windows transfer bundle ${bundle}"
tar -C "${remote_work_dir}" -czf "${bundle}" "${backup_id}"
sha256sum "${bundle}" > "${checksum}"

cat "${snapshot_dir}/MANIFEST.txt"
echo "REMOTE_BUNDLE=${bundle}"
echo "REMOTE_CHECKSUM=${checksum}"
'@

$remoteScript = $remoteScript -replace "`r`n", "`n"

Write-Host "Bereite Remote-Backup auf $target vor..."
Invoke-ExternalCommand -FilePath "ssh" -ArgumentList @($target, "mkdir -p '$RemoteWorkDir'; tr -d '\015' > '$remoteRunner'; chmod 700 '$remoteRunner'") -InputText $remoteScript

Write-Host "Fuehre Backup auf $target aus..."
$remoteOutput = Invoke-ExternalCommandWithOutput -FilePath "ssh" -ArgumentList @(
  $target,
  "'$remoteRunner' '$backupId' '$RemoteRoot' '$DbContainer' '$WikiContainer' '$SearchContainer' '$DbName' '$RemoteWorkDir' '$archiveFiles'"
)
$remoteOutput | ForEach-Object { Write-Host $_ }

Write-Host "Kopiere Backup nach $localBackupDir ..."
Invoke-ExternalCommand -FilePath "scp" -ArgumentList @("${target}:$remoteBundle", $localBackupDir)
Invoke-ExternalCommand -FilePath "scp" -ArgumentList @("${target}:$remoteChecksum", $localBackupDir)

$localBundle = Join-Path $localBackupDir "$backupId.tgz"
$localHash = Get-FileHash -Algorithm SHA256 -Path $localBundle
$localHash.Hash.ToLowerInvariant() | Set-Content -Encoding ASCII -Path (Join-Path $localBackupDir "$backupId.tgz.local.sha256")

if (-not $KeepRemoteBundle.IsPresent) {
  Write-Host "Raeume temporaere Remote-Dateien auf..."
  Invoke-ExternalCommand -FilePath "ssh" -ArgumentList @($target, "rm -rf '$RemoteWorkDir/$backupId' '$remoteBundle' '$remoteChecksum' '$remoteRunner'")
}

Write-Host "Backup abgeschlossen: $localBundle"
Write-Host "SHA256: $($localHash.Hash.ToLowerInvariant())"