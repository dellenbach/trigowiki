# Trigowiki – Betriebsrepo

Infrastructure-as-Code für die produktive MediaWiki-Instanz (Trigonet-Intranet-Wiki).

**Aktuelle Produktionsumgebung (brisen)**

| Komponente | Version | Container |
|---|---|---|
| MediaWiki | 1.45.3 | `mediawiki_wiki_production` (Port 8081) |
| MySQL | 5.7 | `mediawiki_mysql_production` |
| OpenSearch | 1.3.20 | `opensearch_production` |
| OpenResty | alpine | `trigowiki_openresty` (Port 80) |

Produktionsdaten liegen unter `/srv/mediawiki-production/` auf `brisen`.

---

## Schnellreferenz: laufende Produktion

```bash
# Container-Status
docker ps --filter name=mediawiki --filter name=opensearch

# Wiki-Container neu erzeugen (z.B. nach Config-Aenderung)
bash /srv/mediawiki-production/script/start-wiki-production.sh

# Schema-Update nach MW-Aenderungen
docker exec mediawiki_wiki_production bash /srv/mediawiki-production/script/update.sh

# Suchindex neu aufbauen
docker exec mediawiki_wiki_production bash /srv/mediawiki-production/script/reindex-search.sh

# Backup manuell ausloesen
bash /srv/mediawiki-production/script/backup-production-daily.sh

# Logs
docker logs -f --tail=100 mediawiki_wiki_production
```

**Config-Aenderung deployen (von Windows):**

```powershell
.\deploy-trigowiki.ps1
# Erstmalig (SSH-Key einrichten):
.\deploy-trigowiki.ps1 -SetupKey
```

---

## Neuen Server einrichten

```bash
# 1. Repo auf neuen Server klonen
git clone <repo-url> /tmp/trigowiki-repo
cd /tmp/trigowiki-repo

# 2. Erst-Setup: Service-User, Verzeichnisse, Stack starten
sudo bash script/setup-new-server.sh

# 3. Daten vom Produktivserver uebertragen
rsync -a trigowikisvc@brisen:/srv/mediawiki-production/extensions-lts/ /srv/mediawiki-production/extensions-lts/
rsync -a trigowikisvc@brisen:/srv/mediawiki-production/images/         /srv/mediawiki-production/images/
rsync -a trigowikisvc@brisen:/srv/mediawiki-production/Ressourcen/     /srv/mediawiki-production/Ressourcen/

# 4. DB-Dump einspielen (Dump vorher von brisen holen)
bash /srv/mediawiki-production/script/restore-from-backup.sh /pfad/zum/wikidb.sql

# 5. Suchindex aufbauen
docker exec mediawiki_wiki_production bash /srv/mediawiki-production/script/reindex-search.sh

# 6. OpenResty (Port 80) starten
bash /srv/mediawiki-production/script/prepare-openresty.sh

# 7. Backup-Cron einrichten
sudo bash /srv/mediawiki-production/script/setup-cron-trigowikisvc.sh
```

> Voraussetzung: `.env` in `/srv/mediawiki-production/` mit echten Werten (Vorlage: `.env.example`).
> Secrets erzeugen: `python3 -c "import secrets; print(secrets.token_hex(64))"`

---

## Backup

**Backup-Script:** `script/backup-production-daily.sh`
Speichert DB-Dump + Config + Uploads in `/srv/mediawiki-production/backup/daily/` (3 Versionen).

**Cron einrichten (einmalig als root auf dem Server):**

```bash
sudo bash /srv/mediawiki-production/script/setup-cron-trigowikisvc.sh
# Laeuft taeglich um 02:00 Uhr als trigowikisvc
# Log: /srv/mediawiki-production/backup-production.log
```

**Cron pruefen:**

```bash
sudo crontab -u trigowikisvc -l
# Letzte Backup-Ausgabe:
tail -30 /srv/mediawiki-production/backup-production.log
```

**Externer Backup-Transfer (von Windows, geplanter Task):**

```powershell
.\backup-trigowiki-windows.ps1
# Kopiert neuesten Snapshot nach \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\
```

---

## Repo-Inhalt

```
docker-compose.yml          Produktions-Stack (Neuinstallation / Referenz)
.env.example                Vorlage fuer /srv/mediawiki-production/.env
config/
  mediawiki-lts/            Aktive MediaWiki-Konfiguration (LocalSettings, Search, Breadcrumbs, ...)
  openresty/                nginx.conf.template fuer OpenResty-Proxy
script/
  setup-new-server.sh       Erstinstallation neuer Server
  start-wiki-production.sh  Wiki-Container neu erstellen (day-to-day)
  restore-from-backup.sh    DB-Dump importieren
  backup-production-daily.sh  Taegliches Backup
  setup-cron-trigowikisvc.sh  Backup-Cron einrichten
  reindex-search.sh         Suchindex neu aufbauen
  prepare-openresty.sh      OpenResty-Proxy starten/aktualisieren
  install.sh                DB-Schema anlegen (nur fuer leere Instanz)
  update.sh                 MediaWiki-Update (Schema-Migration)
  .env.production.example   Vorlage fuer die Secrets-Datei auf dem Server
deploy-trigowiki.ps1        Config/Scripts nach brisen deployen (Windows)
backup-trigowiki-windows.ps1  Backup-Snapshot von Windows aus holen
Ressourcen/                 Logo, Favicon (statische Assets)
docs/                       Inventar, Config-Review, Betriebsnotizen
```

**Nicht im Repo** (via Backup gesichert):
- DB-Dumps, Uploads (`images/`), Extension-Binaries
- Logs, Caches, Search-Indices, temporaere Daten
- Produktions-Secrets (`.env`)

---

## Wichtige Dateipfade auf brisen

| Pfad | Inhalt |
|---|---|
| `/srv/mediawiki-production/` | Produktionsbasis (Service-User: `trigowikisvc`) |
| `/srv/mediawiki-production/config-lts/` | Aktive MW-Config (von diesem Repo) |
| `/srv/mediawiki-production/extensions-lts/` | CirrusSearch, Elastica, AdvancedSearch, ... |
| `/srv/mediawiki-production/images/` | Uploads |
| `/srv/mediawiki-production/backup/daily/` | Taeglich rotierendes Backup (3 Snapshots) |
| `/srv/mediawiki-production/.env` | Secrets (gitignored; Vorlage: `.env.example`) |
| `/srv/openresty/config/nginx.conf` | OpenResty Live-Config |


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

## Produktionscontainer starten / recreaten

Der Wiki-Produktionscontainer wird ueber `script/start-wiki-production.sh` verwaltet. Das Skript:

- Setzt stabile Docker-DNS-Namen (`mediawiki_mysql_production`, `opensearch_production`) statt Container-IPs
- Liest Secrets aus `/srv/mediawiki-production/.env.production` (nicht im Repo; Vorlage: `script/.env.production.example`)
- Bindet alle LTS-Konfigurationsdateien und Extensions korrekt ein

```bash
# Erstmalige Einrichtung: Secrets anlegen
cp script/.env.production.example /srv/mediawiki-production/.env.production
chmod 600 /srv/mediawiki-production/.env.production
# Dann echte Werte eintragen.

# Container starten / bei Bedarf neu erzeugen
bash /srv/mediawiki-production/script/start-wiki-production.sh
```

Nach jedem Neustart Smoketest:

```bash
curl -sG 'http://trigowiki.trigonet.local/api.php' \
  --data-urlencode 'action=query' \
  --data-urlencode 'list=search' \
  --data-urlencode 'srsearch=Hauptseite' \
  --data-urlencode 'format=json' \
  --data-urlencode 'utf8=1'

docker exec mediawiki_wiki_production \
  curl -sS --max-time 3 http://opensearch_production:9200/_cluster/health
```

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

Das Skript holt den neuesten Snapshot, den `script/backup-production-daily.sh` auf `brisen` erstellt hat, und kopiert ihn nach `\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\trigowiki-backup\<snapshot-id>`. Voraussetzung: SSH-Key des ausfuehrenden Accounts ist fuer `trigowikisvc@brisen` hinterlegt.

Fuer einen vollstaendigeren Snapshot mit Docker-Inventar, Manifest und Transfer-Archiv gibt es zusaetzlich die PowerShell-Variante:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\backup-trigowiki-windows.ps1
```

Auf `brisen` ist fuer den Regelbetrieb `script/backup-production-daily.sh` vorgesehen. Es sichert Datenbank, Uploads und Konfiguration nach `/srv/mediawiki-production/backup/daily/<timestamp>` und entfernt Backups, die aelter als 2 Tage sind.

Fuer die alte produktive Umgebung koennen Pfade und Container explizit ueberschrieben werden:

```powershell
.\backup-trigowiki-windows.ps1 -UserName del -RemoteRoot /srv/mediawiki -DbContainer mediawiki_mysql -WikiContainer mediawiki_wiki -SearchContainer 11f951d24998_elasticsearch -LocalBackupRoot \\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\production
```
