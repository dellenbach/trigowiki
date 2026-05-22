@echo off
setlocal
chcp 65001 >nul

set "SSH_TARGET=trigowikisvc@brisen"
set "REMOTE_BACKUP=/srv/mediawiki-production/backup/daily"
set "BACKUP_DIR=\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\trigowiki-backup"
set "TEMP_DIR=%TEMP%\trigowiki-backup"

REM Neuesten Snapshot-Namen von brisen holen
for /f %%i in ('ssh %SSH_TARGET% "ls -1 %REMOTE_BACKUP% | sort -r | head -1"') do set "SNAPSHOT=%%i"

if "%SNAPSHOT%"=="" (
    echo Kein Snapshot gefunden auf brisen.
    exit /b 1
)

echo Aktueller Snapshot: %SNAPSHOT%
set "TARGET=%BACKUP_DIR%\%SNAPSHOT%"

if exist "%TARGET%" (
    echo Snapshot %SNAPSHOT% bereits lokal vorhanden, wird uebersprungen.
    exit /b 0
)

REM Zuerst in lokales Temp-Verzeichnis laden
set "TEMP_TARGET=%TEMP_DIR%\%SNAPSHOT%"
if exist "%TEMP_TARGET%" rmdir /s /q "%TEMP_TARGET%"
mkdir "%TEMP_TARGET%"

echo Kopiere Datenbankdump...
scp %SSH_TARGET%:%REMOTE_BACKUP%/%SNAPSHOT%/wikidb-production.sql "%TEMP_TARGET%/"
if errorlevel 1 goto :error

echo Kopiere Uploads und Config...
scp %SSH_TARGET%:%REMOTE_BACKUP%/%SNAPSHOT%/uploads-config.tgz "%TEMP_TARGET%/"
if errorlevel 1 goto :error

echo Kopiere Metadaten...
scp %SSH_TARGET%:%REMOTE_BACKUP%/%SNAPSHOT%/metadata.env "%TEMP_TARGET%/"
if errorlevel 1 goto :error

REM Auf DFS-Share kopieren
echo Kopiere auf DFS-Share...
robocopy "%TEMP_TARGET%" "%TARGET%" /e /is /it
if errorlevel 8 goto :error

REM Temp aufraumen
rmdir /s /q "%TEMP_TARGET%"

REM Alte Snapshots auf DFS-Share loeschen (Retention: 3 Tage)
echo Alte Snapshots bereinigen...
powershell -Command "Get-ChildItem '%BACKUP_DIR%' -Directory | Where-Object { $_.LastWriteTime -lt (Get-Date).AddDays(-3) } | ForEach-Object { Write-Host ('Entferne: ' + $_.Name); Remove-Item $_.FullName -Recurse -Force }"

echo Backup abgeschlossen: %TARGET%
exit /b 0

:error
echo Fehler beim Kopieren des Backups.
exit /b 1
