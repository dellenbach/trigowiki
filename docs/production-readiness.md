# Production Readiness

Stand: 2026-05-22

## Kurzfazit

Staging ist fuer Suche und MediaWiki 1.45.3 weitgehend validiert. Produktion ist noch nicht freigabereif fuer den Cutover, aber die wichtigsten Backup-/Restore-Blocker sind jetzt abgebaut.

## Was aktuell gut aussieht

- Staging laeuft mit `mediawiki:1.45.3` auf `http://brisen:8081`.
- Suche laeuft in Staging mit CirrusSearch/Elastica `REL1_45` und OpenSearch `1.3.20`.
- OpenSearch-Health war gruen: ein Node, alle Shards aktiv, keine unassigned Shards.
- CirrusSearch `CheckIndexes` meldete die geprueften Indizes/Shards als `ok`.
- HTTP-Smokes fuer Startseite und Suche lieferten `200`.
- Die zuletzt geprueften Wiki-Logs zeigten keine neuen Fatal-/Exception-/Error-Treffer.
- Staging-Snapshots existieren unter `/srv/mediawiki-staging/backup/snapshots`.
- Der Host wurde bereinigt; `/` hatte nach den letzten Pruefungen ca. 18 GB frei.
- Produktionssnapshot `20260522T141847Z` wurde erstellt und archivseitig validiert.
- Restore-Test des SQL-Dumps in einem isolierten MySQL-5.7-Container war erfolgreich.

## Blocker vor Produktion

1. Produktions-Migrationsrunbook fehlt noch als finale Schritt-fuer-Schritt-Prozedur.
   - Staging ist validiert, aber Produktion braucht ein Wartungsfenster-Runbook mit Stop, Snapshot, Upgrade, Reindex, Smoke-Test und Rollback-Punkt.

2. Host-Ressourcen muessen vor dem Cutover stabil bleiben.
   - OpenSearch-Reindex und MediaWiki-Dumps brauchen temporaer deutlich mehr Speicherplatz.
   - Disk-Watermark-Probleme wurden in Staging bereits gesehen und fuer OpenSearch entschaerft.
   - Der Host-Fuellstand ist aktuell deutlich besser, sollte aber vor dem Wartungsfenster erneut geprueft werden.

3. Produktionsbackup muss noch in den Regelbetrieb.
   - `script/snapshot-production.sh` ist vorhanden und erfolgreich getestet.
   - Offen bleibt ein regelmaessiger Job inklusive Retention und externer Kopie.

4. OpenResty-Cutover ist vorbereitet, aber nicht produktiv umgestellt.
   - Testproxy auf `8088` funktioniert.
   - Port `80` bleibt beim alten Produktions-Wiki bis zum Wartungsfenster.

## Produktionsbackup

Das Repo enthaelt `script/snapshot-production.sh` als reproduzierbaren Produktionssnapshot-Baustein. Das Skript schreibt standardmaessig nach `/srv/mediawiki/backup/snapshots/<timestamp>` und bricht ab, wenn unter `/srv/mediawiki` weniger als 5 GB frei sind.

Der erste erfolgreiche Produktionssnapshot liegt auf `brisen` unter:

```text
/srv/mediawiki/backup/snapshots/20260522T141847Z
```

Validierte Inhalte:

- `wikidb-production.sql`: 111280553 Bytes, SQL-Header lesbar.
- `production-files.tgz`: 1106511357 Bytes, `tar -tzf` erfolgreich.
- Tar-Liste: 127827 Eintraege.
- `RESTORE.md`, Docker-Inventar und Metadaten vorhanden.

Restore-Test:

- Temporärer MySQL-5.7-Container ohne Port-Publishing.
- Importdauer: 15 Sekunden.
- Tabellen: 61.
- Kernzaehlungen: `page=1795`, `revision=12926`, `user=56`, `image=754`.
- Ausgewaehlte Dateien aus dem Tarball wurden erfolgreich extrahiert.
- Testcontainer und Testvolume wurden danach entfernt.

Empfohlener erster Lauf nach dem Aufraeumen von Speicherplatz:

```bash
cd /tmp/trigowiki-production-repo
GIT_COMMIT=<commit> ./script/snapshot-production.sh
```

Danach muss ein Restore-Test gegen Staging oder eine isolierte Testinstanz erfolgen.

## Empfehlung

Noch nicht auf Produktion umstellen. Naechste Reihenfolge:

1. Regelmaessigen Produktionsbackup-Job mit Retention und externer Kopie einrichten.
2. Produktions-Cutover-Runbook schreiben und in Staging trocken testen.
3. Direkt vor dem Wartungsfenster erneut Speicher, Snapshot und Restore-Pfad pruefen.
4. Erst danach Wartungsfenster fuer Produktion planen.
