# Produktionsconfig Review

Stand: 2026-05-21

Quelle: gezielter Export von `/srv/mediawiki/config` auf `brisen` nach `tmp/production-config/`. Der Exportbereich ist ignoriert und gehoert nicht ins Git.

## Ergebnis

Die produktive Konfiguration ist die aktuelle Wahrheit, aber sie ist nicht direkt als Repo-Datei geeignet. Besonders `LocalSettings.php` enthaelt historische Kommentare, alte Such-Tuning-Werte, aktive Erweiterungen, lokale Spezialfaelle und sensible Werte. Sie soll deshalb bereinigt in modulare Repo-Dateien ueberfuehrt werden.

## Uebernommen

- Das produktive Such-Reindex-Skript wurde als `script/reindex-search.sh` versioniert.
- Das Produktionsinventar liegt unter `docs/production-inventory.md`.
- Produktive Spezialkonfiguration wurde in modulare MediaWiki-Dateien aufgeteilt:
   - `config/mediawiki/Permissions.php`
   - `config/mediawiki/Extensions.php`
   - `config/mediawiki/UploadSettings.php`
   - `config/mediawiki/EmbeddingSettings.php`
- Die exportierten Rohdateien bleiben unter `tmp/production-config/` und sind durch `.gitignore` ausgeschlossen.

## Nicht blind uebernommen

- `LocalSettings.php`: weicht stark von `config/mediawiki/LocalSettings.php` ab und muss in einzelne, wartbare Konfigurationsbausteine zerlegt werden.
- `nginx.conf`: die lokale Datei enthaelt bereits eine aufgeraeumte Appsmith-Proxy-Struktur mit `upstream appsmith_backend`. Sie ist nicht identisch mit Produktion, aber offenbar eine bereinigte Variante. Vor einem Commit muss entschieden werden, ob diese Variante produktiv gewollt ist.

## Naechste Arbeiten

1. Secrets aus versionierten Dateien entfernen:
   - Datenbank-Passwoerter
   - Secret Key
   - Upgrade Key
   - SMTP-Zugangsdaten, falls vorhanden
2. Extension-Kompatibilitaetsmatrix fuer die aktuelle MediaWiki-LTS-Version erstellen.
3. Entscheiden, ob `config/nginx/nginx.conf` in der lokalen bereinigten Form committed werden soll.

## Secret-Stand

`docker-compose.yml` verwendet fuer Datenbankpasswoerter und `MEDIAWIKI_SECRET_KEY` Environment-Variablen. Die benoetigten Variablen sind in `.env.example` dokumentiert; die echte `.env` bleibt ignoriert.

Die produktive `LocalSettings.php` enthaelt weiterhin reale Werte im exportierten `tmp/production-config/`-Bereich. Dieser Bereich ist absichtlich ignoriert und darf nicht committed werden.

## Risiko-Hinweise

- Die produktive `LocalSettings.php` laedt einige Erweiterungen per altem `require_once` statt durchgehend per `wfLoadExtension`. Beim LTS-Upgrade muss jede Erweiterung einzeln geprueft werden.
- Der produktive MediaWiki-Core wird derzeit ueber `/srv/mediawiki/includes` gemountet. Dieser Zustand sollte nicht als Zielarchitektur uebernommen werden.
- Suchindizes werden beim Upgrade neu aufgebaut, nicht aus Elasticsearch 5.4 uebernommen.