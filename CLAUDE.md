# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Was dieses Repo ist

Trigowiki ist kein MediaWiki-Quellcode, sondern das **Infrastructure-as-Code-Repo** für eine produktive MediaWiki-Instanz (Trigonet-Intranet-Wiki). Es verwaltet Docker-Konfiguration, Maintenance-Skripte, MediaWiki-Config-Dateien und Deployment-Prozeduren. Produktionsdaten (DB, Uploads, Extensions) liegen außerhalb des Repos auf dem Server.

## Wichtige Befehle

### Starten / Bauen
```bash
docker compose up -d --build        # Produktions-Stack starten/neu bauen
docker compose -f docker-compose.staging.yml up -d --build  # Staging
docker compose ps
docker compose logs -f --tail=200
```

### Erstinstallation (einmalig)
```bash
docker exec -it mediawiki_wiki /script/install.sh <admin-user> <admin-password>
docker exec -it mediawiki_wiki /script/reindex-search.sh
```

### Laufende Wartung
```bash
docker exec -it mediawiki_wiki /script/update.sh          # DB-Migrations nach Konfig-Änderung
docker exec -it mediawiki_wiki /script/reindex-search.sh  # Suchindex neu aufbauen
```

### Konfiguration validieren
```bash
docker exec -it mediawiki_wiki nginx -t   # Nginx-Config prüfen
```

### Backup / Deployment (Windows → brisen)
```powershell
.\deploy-trigowiki.ps1 -HostName brisen -UserName trigowikisvc
.\backup-trigowiki-windows.ps1
```

## Architektur

### Docker-Services (`docker-compose.yml`)

| Service | Image | Zweck |
|---|---|---|
| `mediawiki_wiki` | Custom (Dockerfile) | Nginx + PHP-FPM + Parsoid via Supervisor |
| `mediawiki_mysql` | MySQL 5.7 | Datenbank (`wikidb`) |
| `elasticsearch` | Elasticsearch 5.4 | Volltext-Suche (CirrusSearch) |

Alle Services laufen im Bridge-Netz `wikinet` (10.0.0.0/24).

### Prozesse im mediawiki_wiki-Container

Supervisor verwaltet drei Prozesse:
- **Nginx** — HTTP-Server auf Port 8080, proxied Appsmith (`/app/`) auf 10.203.2.50:8080
- **PHP-FPM** — FastCGI-Prozessor für MediaWiki PHP
- **Parsoid** — Visual-Editor-Backend (Node.js, Port 8142)

### MediaWiki-Konfiguration (`config/mediawiki/`)

Die Konfiguration ist modular aufgeteilt — `LocalSettings.php` included alle anderen:

| Datei | Inhalt |
|---|---|
| `LocalSettings.php` | Kern-Einstellungen, DB-Verbindung (via Env-Vars) |
| `Extensions.php` | Extensions laden und konfigurieren |
| `Permissions.php` | Gruppen, Rechte, Zugriffssteuerung |
| `UploadSettings.php` | Datei-Uploads (max 500 MB, ImageMagick) |
| `EmbeddingSettings.php` | Externe Einbettungen (draw.io, SharePoint, SVG) |
| `CirrusSearchTuning.php` | Suchgewichtung, Phrase-Suggestions |
| `ExtraLocalSettings.php` | E-Mail, Auth, Lizenz |

### Datenpfade auf dem Host (brisen)

- `/srv/mediawiki/` — Produktion (Extensions, Uploads, Backups)
- `/srv/mediawiki-staging/` — Staging
- `/srv/mediawiki/backup/daily/` — Tägliche Backups (2 Tage Retention)

## Umgebungsvariablen

Kopie von `.env.example` → `.env`, dann befüllen:

| Variable | Zweck |
|---|---|
| `TRIGOWIKI_DB_ROOT_PASSWORD` | MySQL root-Passwort |
| `MEDIAWIKI_SECRET_KEY` | MediaWiki-Sicherheitstoken |
| `STAGING_DB_ROOT_PASSWORD` | Staging-MySQL |
| `STAGING_MEDIAWIKI_SECRET_KEY` | Staging-Secret |
| `STAGING_HTTP_PORT` | Staging-Port (default 8081) |

Container-interne Einstellungen (in Dockerfile/Supervisor):
- `PHPFPM_WORKERS_START/MIN/MAX` — PHP-FPM-Prozess-Pool
- `PARSOID_WORKERS` — Parsoid-Worker-Anzahl

## Aktueller Systemzustand

- MediaWiki **1.30**, PHP **7.0.27**, Elasticsearch **5.4.3** — veraltet
- LTS-Upgrade auf MW **1.43** ist geplant, Strategie in [docs/lts-upgrade-plan.md](docs/lts-upgrade-plan.md)
- Staging-Umgebung zum risikofreien Testen von Upgrades vorhanden (`docker-compose.staging.yml`)

## Was ins Repo gehört / was nicht

**Versioniert**: Config-Dateien, Skripte, Dockerfile, Dokumentation, Custom-Extensions/Patches

**Nicht versioniert** (Backup, aber kein Git): Produktions-DB-Dumps, Uploads, Extension-Binaries

**Ignoriert**: Thumbnails, Caches, Logs, Search-Indices, temporäre Dateien
