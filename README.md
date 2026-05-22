# Trigowiki Betrieb

Dieses Repository ist der Bauplan fuer Trigowiki. Es soll die Umgebung reproduzierbar machen, aber keine produktiven Inhalte, Uploads, Backups oder komplette MediaWiki-Releases versionieren.

## Was ins Repository gehoert

- `docker-compose.yml`: Services, Netzwerke, Volumes und Server-Mounts
- `Dockerfile`: Image-Anpassungen, solange ein eigenes MediaWiki-Image gebaut wird
- `docker-entrypoint.sh`: Container-Startlogik
- `config/`: MediaWiki-, Nginx-, PHP-FPM-, Parsoid-, Supervisor- und Suchkonfiguration
- `script/`: Wartungsskripte fuer Installation und Updates
- `script/reindex-search.sh`: Suchindex und Suggester neu aufbauen
- `deploy-trigowiki.ps1`: Deployment-Hilfsskript von Windows aus
- `docs/`: Inventar, Restore-, Upgrade- und Betriebsnotizen

Eigene MediaWiki-Erweiterungen, Skins oder Patches sollen gezielt abgelegt werden, zum Beispiel unter `extensions-local/`, `skins-local/` oder `patches/`. Komplette Standard-Extensions oder MediaWiki-Core-Verzeichnisse gehoeren nicht in dieses Betriebsrepo, ausser eine lokale Aenderung ist dokumentiert und nicht anders reproduzierbar.

## Was nicht ins Repository gehoert

- Uploads, Bilder und Thumbnails: `mediawiki/images/`
- Docker-, Datenbank- und Elasticsearch-Laufzeitdaten: `volumes/`
- Backups, Dumps und Archive
- MediaWiki-Core-Abzuege wie `mediawiki/includes/`
- komplette produktive Extension-/Skin-Abzuege wie `mediawiki/extensions/` oder `mediawiki/skins/`
- Logs, Caches, Temp- und Staging-Verzeichnisse

Diese Daten muessen ueber Backup- und Restore-Prozesse gesichert werden, nicht ueber Git.

## Produktion als Quelle

Die produktive Umgebung auf `brisen` ist aktuell die Quelle der Wahrheit. Vor einem Upgrade wird sie inventarisiert und danach in drei Gruppen eingeteilt:

1. **Versionieren**: Konfiguration, eigene Skripte, eigene Anpassungen, Runbooks.
2. **Sichern, aber nicht versionieren**: Datenbank, Uploads, Config-Backups, produktive Daten.
3. **Neu erzeugen oder ignorieren**: Thumbnails, Caches, Logs, Suchindizes, Temp-Dateien.

Der aktuelle produktive Stand wurde in `docs/production-inventory.md` festgehalten. Die gezielt exportierte Produktionskonfiguration wurde in `docs/production-config-review.md` bewertet.

## Start und Wartung

Vor dem Start muss lokal bzw. auf dem Server eine `.env`-Datei mit den benoetigten Secrets aus `.env.example` angelegt werden. `.env` ist absichtlich ignoriert und gehoert nicht ins Git.

Start im Repository bzw. auf dem Server im Zielpfad:

```bash
docker compose up -d --build
```

Status und Logs:

```bash
docker compose ps
docker compose logs -f --tail=200
```

MediaWiki-Update im Container:

```bash
docker exec -it mediawiki_wiki /script/update.sh
```

Suchindex neu aufbauen:

```bash
docker exec -it mediawiki_wiki /script/reindex-search.sh
```

Erstinstallation der Datenbank:

```bash
docker exec -it mediawiki_wiki /script/install.sh <username> <password>
```

Hinweis: Auf `brisen` war in der bisherigen Diagnose direkte `docker`-Nutzung verlaesslicher als `docker compose`. Das Deployment-Skript muss vor dem Upgrade noch an die reale Zielumgebung angepasst werden.

## Deployment von Windows

Das bestehende Deployment-Skript ist weiterhin vorhanden:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\deploy-trigowiki.ps1 -HostName brisen -UserName del -SkipRun
```

Vor produktiver Nutzung muessen Zielpfad, Benutzer und Compose-/Docker-Aufruf gegen die aktuelle Produktion geprueft werden.

## Backup von Windows

Das neue produktive Wiki kann von Windows aus mit einem einfachen Batch-Skript gesichert werden:

```bat
backup_trigowiki_new_wiki.bat
```

Das Skript sichert `trigowikisvc@brisen:/srv/mediawiki-production`, erzeugt einen Datenbankdump aus `mediawiki_mysql_production` und kopiert `images`, `config-lts` und `Ressourcen` nach `\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\new-wiki`.

Fuer einen vollstaendigeren Snapshot mit Docker-Inventar, Manifest und Transfer-Archiv gibt es zusaetzlich die PowerShell-Variante:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\backup-trigowiki-windows.ps1
```

Fuer die alte produktive Umgebung koennen Pfade und Container explizit ueberschrieben werden:

```powershell
.\backup-trigowiki-windows.ps1 -UserName del -RemoteRoot /srv/mediawiki -DbContainer mediawiki_mysql -WikiContainer mediawiki_wiki -SearchContainer 11f951d24998_elasticsearch -LocalBackupRoot \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\production
```
