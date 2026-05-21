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

Ziel ist eine reproduzierbare zweite Staging-Variante mit aktueller MediaWiki-LTS-Version, ohne die produktive Instanz zu veraendern.

Der Upgrade-Pfad sollte nicht direkt auf Produktion angewendet werden. Erst wenn die neue Staging-Variante erfolgreich laeuft, wird ein Produktions-Runbook erstellt.

## Wichtige Risiken

- Der Sprung von MediaWiki 1.30 auf eine aktuelle LTS-Version ist gross.
- PHP 7.0 ist fuer aktuelle MediaWiki-Versionen zu alt.
- Elasticsearch 5.4 ist fuer moderne CirrusSearch-Versionen zu alt.
- Viele Erweiterungen liegen als historischer Host-Bestand vor, inklusive Duplikaten wie `CirrusSearch29`, `Elastica29`, `VisualEditor_ori`, `VisualEditorx` und `VisualEditorxxx`.
- Alte Skins und Erweiterungen muessen einzeln gegen die Zielversion geprueft werden.
- Der Job-Queue-Bestand enthaelt alte CirrusSearch-Jobs mit Fehlerzaehlern; fuer neue Staging-Laeufe sollte die Suche frisch indiziert und die Queue separat bewertet werden.

## Vorgeschlagene Reihenfolge

1. Neuen Upgrade-Branch oder neuen Commit-Abschnitt fuer LTS-Staging beginnen.
2. Zweite Staging-Variante definieren, z. B. Port `8082`, Container-Suffix `_lts`, Root `/srv/mediawiki-staging-lts`.
3. Neues Docker-Image mit aktueller PHP-/MediaWiki-LTS-Basis bauen.
4. Erweiterungen aufraeumen und nur kompatible Versionen in das neue Image oder einen reproduzierbaren Host-Pfad aufnehmen.
5. Datenbankdump aus Produktion importieren.
6. `maintenance/update.php` gegen die neue Version ausfuehren.
7. Neue Suchkomponente aufbauen. Elasticsearch 5.4 nicht weiterverwenden; passende OpenSearch-/Elasticsearch-Version fuer die Ziel-CirrusSearch-Version waehlen.
8. Uploads und Ressourcen mounten, Logo und statische Ressourcen pruefen.
9. Suche, Login, Bildanzeige, VisualEditor, PDF/Widgets/SyntaxHighlight und Spezialseiten testen.
10. Erst danach Produktionsmigration planen.

## Naechste technische Aufgabe

Als naechstes sollte eine neue Staging-LTS-Konfiguration vorbereitet werden, getrennt von der aktuellen Alt-Staging-Instanz:

- `STAGING_LTS_ROOT=/srv/mediawiki-staging-lts`
- Port `8082`
- eigene DB- und Such-Volumes
- eigene Container-Namen mit Suffix `_lts`
- neues Dockerfile fuer die Ziel-LTS-Version

Damit bleibt `http://brisen:8081/` als Referenz fuer den reproduzierten Altbestand erhalten, waehrend `http://brisen:8082/` fuer das Upgrade-Experiment genutzt wird.

## Akzeptanzkriterien fuer LTS-Staging

- Container starten reproduzierbar aus Repo-Skripten.
- DB-Upgrade laeuft ohne manuelle DB-Eingriffe durch.
- `Special:Version` zeigt die Ziel-LTS-Version.
- Wiki-Startseite und Login funktionieren.
- Logo und Upload-Dateien werden ausgeliefert.
- Suche liefert nach Login Ergebnisse ohne Elasticsearch-/OpenSearch-Transportfehler.
- Reindex laeuft vollstaendig durch.
- Keine kritischen Fehler in den Containerlogs nach Smoke-Test.
