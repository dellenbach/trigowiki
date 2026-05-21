# Produktionsinventar

Stand: 2026-05-21

Quelle: read-only Inventar ueber `ssh del@brisen`.

## Host und Container

- Host: `brisen`
- Benutzer fuer Diagnose: `del`
- Laufende relevante Container:
  - `mediawiki_wiki` mit Image `trigowiki`
  - `mediawiki_mysql` mit Image `mysql:5.7`
  - `11f951d24998_elasticsearch` mit Image `elasticsearch:5.4`
  - `appsmith` mit Image `appsmith/appsmith-ce:latest`

## Versionen

- MediaWiki: `1.30.0`
- PHP im Wiki-Container: `7.0.27`
- MySQL: `5.7.22`
- Elasticsearch: `5.4.3`, Lucene `6.5.1`

Diese Versionen sind Altbestand. Fuer das geplante Upgrade sollte zuerst eine aktuelle MediaWiki-LTS-Linie mit passendem PHP-, Datenbank- und Such-Backend-Ziel definiert werden.

## Produktive Mounts des Wiki-Containers

- `/srv/mediawiki/extensions` -> `/var/www/mediawiki/extensions`
- `/srv/mediawiki/config/LocalSettings.php` -> `/var/www/mediawiki/LocalSettings.php`
- `/srv/mediawiki/skins/Vector` -> `/var/www/mediawiki/skins/Vector`
- `/srv/mediawiki/images` -> `/var/www/mediawiki/images`
- `/srv/mediawiki/config/nginx.conf` -> `/etc/nginx/nginx.conf`
- `/srv/mediawiki/includes` -> `/var/www/mediawiki/includes`
- Docker-Volumes fuer `/var/cache/nginx`, `/data` und `/images`

Der Mount von `/srv/mediawiki/includes` bedeutet, dass der produktive MediaWiki-Core derzeit vom Host kommt. Fuer ein Upgrade sollte dieser Zustand aufgeloest oder mindestens als Patch-Quelle dokumentiert werden.

## Produktive Config-Dateien

- `CirrusSearchTuning.php`
- `LocalSettings.php`
- `LocalSettings.php.bak-`
- `LocalSettings.php.bak-20260520-200423`
- `nginx.conf`
- `reindex.sh`

Backups wie `*.bak` gehoeren nicht ins Git. Die aktive Konfiguration gehoert bereinigt und dokumentiert ins Repo.

## Aktive Erweiterungen in `LocalSettings.php`

Direkt geladen oder per `require_once` eingebunden:

- `VisualEditor`
- `UserMerge`
- `Cite`
- `CiteThisPage`
- `ConfirmEdit`
- `Gadgets`
- `ImageMap`
- `InputBox`
- `Interwiki`
- `LocalisationUpdate`
- `Nuke`
- `ParserFunctions`
- `PdfHandler`
- `Poem`
- `Renameuser`
- `SpamBlacklist`
- `SyntaxHighlight_GeSHi`
- `TitleBlacklist`
- `WikiEditor`
- `JSBreadCrumbs`
- `Elastica`
- `CirrusSearch`
- `TextExtracts`
- `TemplateData`
- `Scribunto`
- `DeletePagesForGood`
- `DeleteBatch`
- `ClipUpload`
- `MsUpload`
- `DrawioEditor`
- `NativeSvgHandler`
- `PDFEmbed`
- `Widgets`
- `Iframe`

Diese Liste ist die Startbasis fuer die Extension-Kompatibilitaetsmatrix des LTS-Upgrades.

## Produktive Extension-Verzeichnisse

Vorhanden unter `/srv/mediawiki/extensions`:

- `BreadCrumbs`
- `BreadCrumbs2`
- `CirrusSearch`
- `CirrusSearch29`
- `Cite`
- `CiteThisPage`
- `ClipUpload`
- `ConfirmEdit`
- `DeleteBatch`
- `DeletePagesForGood`
- `DrawioEditor`
- `DrawioEditorNEW`
- `Elastica`
- `Elastica29`
- `flowchartwiki`
- `Gadgets`
- `Iframe`
- `ImageMap`
- `InputBox`
- `Interwiki`
- `JSBreadCrumbs`
- `LocalisationUpdate`
- `MsUpload`
- `NativeSvgHandler`
- `Nuke`
- `ParserFunctions`
- `PDFEmbed`
- `PdfHandler`
- `Poem`
- `Renameuser`
- `Scribunto`
- `SimpleAntiSpam`
- `SpamBlacklist`
- `SyntaxHighlight_GeSHi`
- `TemplateData`
- `TextExtracts`
- `TitleBlacklist`
- `UserMerge`
- `Vector`
- `VisualEditor`
- `VisualEditor_ori`
- `VisualEditorx`
- `VisualEditorxxx`
- `Widgets`
- `WikiEditor`

Nicht jedes vorhandene Verzeichnis ist aktiv. Fuer das Upgrade zaehlt zuerst die aktive Liste aus `LocalSettings.php`; alte Kopien wie `VisualEditor_ori`, `VisualEditorx`, `VisualEditorxxx`, `CirrusSearch29` und `Elastica29` sind Kandidaten fuer Backup statt Versionierung.

## Repository-Konsequenz

Im Git sollen nur Betriebsdateien, dokumentierte eigene Anpassungen und reproduzierbare Konfiguration landen. Produktive Uploads, Runtime-Daten, Backups, komplette Core-Abzuege und unklassifizierte Extension-Kopien bleiben ausserhalb von Git.