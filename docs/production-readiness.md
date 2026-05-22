# Production Readiness

Stand: 2026-05-22

## Kurzfazit

Staging ist fuer Suche und MediaWiki 1.45.3 weitgehend validiert. Produktion ist noch nicht freigabereif.

## Was aktuell gut aussieht

- Staging laeuft mit `mediawiki:1.45.3` auf `http://brisen:8081`.
- Suche laeuft in Staging mit CirrusSearch/Elastica `REL1_45` und OpenSearch `1.3.20`.
- OpenSearch-Health war gruen: ein Node, alle Shards aktiv, keine unassigned Shards.
- CirrusSearch `CheckIndexes` meldete die geprueften Indizes/Shards als `ok`.
- HTTP-Smokes fuer Startseite und Suche lieferten `200`.
- Die zuletzt geprueften Wiki-Logs zeigten keine neuen Fatal-/Exception-/Error-Treffer.
- Staging-Snapshots existieren unter `/srv/mediawiki-staging/backup/snapshots`.

## Blocker vor Produktion

1. Freier Speicher ist zu knapp.
   - `/` und `/srv` auf `brisen` waren bei der letzten Pruefung zu 96 Prozent belegt.
   - Frei waren nur ca. 2.2 GB.
   - Das ist zu wenig fuer sichere Produktionssnapshots, Dumps, Rollback und Such-Reindex.

2. Produktionsbackup ist nicht sauber automatisiert.
   - `/srv/mediawiki/backup` existierte, war aber praktisch leer.
   - Es gab keine sichtbaren MediaWiki-Backup-Cronjobs oder systemd-Timer.
   - Staging-Backups existieren, ersetzen aber kein Produktionsbackup.

3. Restore wurde noch nicht getestet.
   - Ein Backup ist erst produktionsreif, wenn ein Restore auf Staging oder in eine isolierte Testinstanz erfolgreich durchgespielt wurde.

4. Produktions-Migrationsrunbook fehlt noch als finale Schritt-fuer-Schritt-Prozedur.
   - Staging ist validiert, aber Produktion braucht ein Wartungsfenster-Runbook mit Stop, Snapshot, Upgrade, Reindex, Smoke-Test und Rollback-Punkt.

5. Host-Ressourcen muessen vor dem Cutover stabilisiert werden.
   - OpenSearch-Reindex und MediaWiki-Dumps brauchen temporair deutlich mehr Speicherplatz.
   - Disk-Watermark-Probleme wurden in Staging bereits gesehen und fuer OpenSearch entschärft; der Host-Fuellstand bleibt trotzdem ein Betriebsrisiko.

## Produktionsbackup

Das Repo enthaelt nun `script/snapshot-production.sh` als reproduzierbaren Produktionssnapshot-Baustein. Das Skript schreibt standardmaessig nach `/srv/mediawiki/backup/snapshots/<timestamp>` und bricht ab, wenn unter `/srv/mediawiki` weniger als 5 GB frei sind.

Empfohlener erster Lauf nach dem Aufraeumen von Speicherplatz:

```bash
cd /tmp/trigowiki-production-repo
GIT_COMMIT=<commit> ./script/snapshot-production.sh
```

Danach muss ein Restore-Test gegen Staging oder eine isolierte Testinstanz erfolgen.

## Empfehlung

Noch nicht auf Produktion umstellen. Erst diese Reihenfolge abarbeiten:

1. Speicher freimachen oder Volume erweitern, Ziel mindestens 10 bis 15 GB frei.
2. Produktionssnapshot mit `script/snapshot-production.sh` erzeugen.
3. Restore-Test aus diesem Snapshot durchfuehren.
4. Produktions-Cutover-Runbook schreiben und in Staging trocken testen.
5. Erst danach Wartungsfenster fuer Produktion planen.
