# MediaWiki-LTS-Upgrade-Plan

Stand: 2026-05-21

## Ausgangslage

Die aktuelle Staging-Basis laeuft stabil unter dem Service-User `trigowikisvc` mit Dateien unter `/srv/mediawiki-staging`.

Aktueller Altbestand:

- MediaWiki: 1.30.0
- PHP: 7.0.27
- MySQL: 5.7.22
- Elasticsearch: 5.4.3 / Lucene 6.5.1
- Staging-URL: `http://brisen:8081/`
- Staging-Container: `mediawiki_wiki_staging`, `mediawiki_mysql_staging`, `elasticsearch_staging`

Die Staging-Suche ist funktionsfaehig, der Suchindex wird beim Refresh neu aufgebaut. Anonyme Benutzer sehen erwartungsgemaess Login-Pflicht statt Suchresultate.

## Upgrade-Ziel

Ziel ist ein reproduzierbares In-place-Upgrade der bestehenden Staging-Instanz auf `http://brisen:8081/` auf eine aktuelle MediaWiki-LTS-Version, ohne die produktive Instanz zu veraendern.

Der Upgrade-Pfad sollte nicht direkt auf Produktion angewendet werden. Erst wenn das In-place-Upgrade auf Staging erfolgreich laeuft, wird ein Produktions-Runbook erstellt.

## Wichtige Risiken

- Der Sprung von MediaWiki 1.30 auf eine aktuelle LTS-Version ist gross.
- PHP 7.0 ist fuer aktuelle MediaWiki-Versionen zu alt.
- Elasticsearch 5.4 ist fuer moderne CirrusSearch-Versionen zu alt.
- Viele Erweiterungen liegen als historischer Host-Bestand vor, inklusive Duplikaten wie `CirrusSearch29`, `Elastica29`, `VisualEditor_ori`, `VisualEditorx` und `VisualEditorxxx`.
- Alte Skins und Erweiterungen muessen einzeln gegen die Zielversion geprueft werden.
- Der Job-Queue-Bestand enthaelt alte CirrusSearch-Jobs mit Fehlerzaehlern; fuer neue Staging-Laeufe sollte die Suche frisch indiziert und die Queue separat bewertet werden.

## Vorgeschlagene Reihenfolge

1. Neuen Upgrade-Branch oder neuen Commit-Abschnitt fuer LTS-Staging beginnen.
2. Snapshot der bestehenden Staging-Instanz erzeugen.
3. Datenbankdump aus Produktion in Staging importieren.
4. Zuerst auf MediaWiki 1.35 migrieren; MediaWiki 1.43 verweigert direkte Upgrades von Versionen vor 1.35.
5. Nach dem 1.35-Lauf `cleanupUsersWithNoId.php --prefix 'Imported>' --assign` und danach `maintenance/update.php --quick` ausfuehren.
6. Denselben Staging-Datenbank-Volume ohne erneuten Import auf MediaWiki 1.43 migrieren.
7. Neue Suchkomponente aufbauen. Elasticsearch 5.4 nicht weiterverwenden; passende OpenSearch-/Elasticsearch-Version fuer die Ziel-CirrusSearch-Version waehlen.
8. Uploads und Ressourcen mounten, Logo und statische Ressourcen pruefen.
9. Suche, Login, Bildanzeige, VisualEditor, PDF/Widgets/SyntaxHighlight und Spezialseiten testen.
10. Erst danach Produktionsmigration planen.

## Snapshot vor dem Upgrade

Vor jedem In-place-Upgrade wird ein Snapshot erstellt:

```bash
cd /tmp/trigowiki-staging-repo-trigowikisvc
./script/snapshot-staging.sh
```

Der Snapshot landet standardmaessig unter `/srv/mediawiki-staging/backup/snapshots/<timestamp>` und enthaelt:

- Metadaten und Docker-Inventar.
- Dump der Staging-Datenbank.
- Archiv von `/srv/mediawiki-staging`.
- Wiederherstellungsnotizen.

## Naechste technische Aufgabe

Die bestehende Staging-Konfiguration wurde fuer einen ersten In-place-LTS-Smoke vorbereitet:

- `http://brisen:8081/` bleibt Upgrade-Ziel.
- vorhandene Container-Namen mit Suffix `_staging` werden weiterverwendet.
- `config/mediawiki-lts/LocalSettings.php` ist eine minimale 1.35/1.43-kompatible Staging-Konfiguration.
- `script/staging-lts-upgrade.sh` orchestriert den validierten Pfad `1.30 -> 1.35 -> 1.43`.
- Suchdienst separat modernisieren, weil Elasticsearch 5.4 nicht zur modernen CirrusSearch-Zielversion passt.

Wenn das In-place-Upgrade scheitert, wird `8081` aus Snapshot und aktuellem Git-Stand wiederhergestellt.

## Validierter LTS-Smoke vom 2026-05-21

Der erste LTS-Smoke auf `http://brisen:8081/` wurde mit dem bestehenden Produktionsdump durchgefuehrt:

- Direkter Sprung `1.30 -> 1.43` scheiterte erwartungsgemaess mit: `Can not upgrade from versions older than 1.35`.
- Zwischenupgrade mit `mediawiki:1.35` lief durch.
- Die 1.35-Actor-Migration meldete zunaechst 107 alte anonyme Benutzerzeilen; `cleanupUsersWithNoId.php --prefix 'Imported>' --assign` und ein erneutes `update.php --quick` bereinigten den Stand.
- Weiteres Upgrade mit `mediawiki:1.43` lief durch.
- `mediawiki_wiki_staging` laeuft mit `mediawiki:1.43` auf `0.0.0.0:8081->80/tcp`.
- `http://localhost:8081/` liefert `200 OK` und zeigt erwartungsgemaess die deutsche Login-Pflicht.
- Das Logo unter `/resources/trigowiki/trigonet_Logo_pos_ohneClaim_RGB.svg` liefert `200 OK` mit `image/svg+xml`.
- Containerlogs zeigten nach dem Smoke keine Treffer fuer `Fatal`, `Error`, `Exception` oder `Warning`.

Dieser Smoke laeuft bewusst ohne CirrusSearch und ohne historische Custom-/Legacy-Erweiterungen. Suche, OpenSearch/CirrusSearch, VisualEditor-Details und alte Spezialerweiterungen sind Folgearbeiten.

## Akzeptanzkriterien fuer LTS-Staging

- Container starten reproduzierbar aus Repo-Skripten.
- DB-Upgrade laeuft ohne manuelle DB-Eingriffe durch.
- `Special:Version` zeigt die Ziel-LTS-Version.
- Wiki-Startseite und Login funktionieren.
- Logo und Upload-Dateien werden ausgeliefert.
- Suche liefert nach Login Ergebnisse ohne Elasticsearch-/OpenSearch-Transportfehler.
- Reindex laeuft vollstaendig durch.
- Keine kritischen Fehler in den Containerlogs nach Smoke-Test.
