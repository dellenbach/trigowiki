@echo off
setlocal
chcp 65001 >nul

REM Einfaches Windows-Backup fuer das neue Trigowiki auf brisen.
REM Sichert wie das alte Backup: Datenbankdump plus Uploads/Config.

set "SSH_TARGET=trigowikisvc@brisen"
set "REMOTE_ROOT=/srv/mediawiki-production"
set "DB_CONTAINER=mediawiki_mysql_production"
set "DB_NAME=wikidb"
set "BACKUP_DIR=\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\new-wiki"

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

echo Mysql Backup
ssh %SSH_TARGET% "docker exec %DB_CONTAINER% sh -c 'exec mysqldump -uroot -p^"$MYSQL_ROOT_PASSWORD^" %DB_NAME%'" > "%BACKUP_DIR%\trigowiki_new_wiki.sql"
if errorlevel 1 goto :error

echo Filebackup

REM Uploads
scp -r %SSH_TARGET%:%REMOTE_ROOT%/images "%BACKUP_DIR%\"
if errorlevel 1 goto :error

REM LTS-Config des neuen Wikis
scp -r %SSH_TARGET%:%REMOTE_ROOT%/config-lts "%BACKUP_DIR%\"
if errorlevel 1 goto :error

REM Statische Ressourcen wie Logo-Dateien
scp -r %SSH_TARGET%:%REMOTE_ROOT%/Ressourcen "%BACKUP_DIR%\"
if errorlevel 1 goto :error

echo Backup abgeschlossen: %BACKUP_DIR%
exit /b 0

:error
echo Backup fehlgeschlagen.
exit /b 1