# Production Readiness

Stand: 2026-05-22

## Kurzfazit

Der Cutover auf das neue MediaWiki 1.45.3 hinter OpenResty ist erfolgt. Die wichtigsten Backup-/Restore-Blocker wurden vorher abgebaut und die ersten Produktions-Smokes sind erfolgreich.

## Was aktuell gut aussieht

- Das neue Wiki laeuft mit `mediawiki:1.45.3` im Container `mediawiki_wiki_production` auf `http://brisen:8081` und wird produktiv ueber OpenResty auf Port `80` bedient.
- Die aktiven Dateien liegen unter `/srv/mediawiki-production`.
- Die aktive Produktions-Datenbank laeuft als `mediawiki_mysql_production`, der Suchcontainer als `opensearch_production`.
- Die aktiven Docker-Volumes heissen `mediawiki_mysql_production` und `opensearch_production_data`; alte `*staging*`-Volumes wurden entfernt.
- Der Wiki-Container setzt `MEDIAWIKI_DB_HOST=mediawiki_mysql_production` und `MEDIAWIKI_SEARCH_HOST=opensearch_production` (stabile Docker-DNS-Namen, keine IPs). Erststart und Recreate erfolgen ueber `script/start-wiki-production.sh`.
- OpenResty laeuft als `trigowiki_openresty` auf `0.0.0.0:80 -> 80/tcp`.
- Der alte Produktionscontainer `mediawiki_wiki` ist gestoppt und bleibt als Rollback-Punkt vorhanden.
- Suche laeuft in Produktion mit CirrusSearch/Elastica `REL1_45` und OpenSearch `1.3.20`.
- OpenSearch-Health war gruen: ein Node, alle Shards aktiv, keine unassigned Shards.
- CirrusSearch `CheckIndexes` meldete die geprueften Indizes/Shards als `ok`.
- HTTP-Smokes fuer Startseite und Suche lieferten `200`.
- Die zuletzt geprueften Wiki-Logs zeigten keine neuen Fatal-/Exception-/Error-Treffer.
- Der alte Pfad `/srv/mediawiki-staging` wurde entfernt.
- Staging-Container, das Netzwerk `trigowiki_staging` und die alten Staging-Volumes wurden entfernt.
- Der Host wurde bereinigt; `/` hatte nach den letzten Pruefungen ca. 18 GB frei.
- Produktionssnapshot `20260522T141847Z` wurde erstellt und archivseitig validiert.
- Restore-Test des SQL-Dumps in einem isolierten MySQL-5.7-Container war erfolgreich.
- Produktions-Smokes nach dem Cutover waren erfolgreich: Startseite, Suche `postgres`, Suche `gres` mit `go=Seite`, `Postgres_Cluster`, Bildauslieferung, Appsmith unter `/app` und `appsmith.trigonet.local`.

## Offene Nacharbeiten

1. Host-Ressourcen muessen weiter stabil bleiben.
   - OpenSearch-Reindex und MediaWiki-Dumps brauchen temporaer deutlich mehr Speicherplatz.
   - Disk-Watermark-Probleme wurden bereits gesehen und fuer OpenSearch entschaerft.
   - Der Host-Fuellstand lag nach dem Cutover bei ca. 18 GB frei.

2. Produktionsbackup laeuft im Regelbetrieb.
   - `script/backup-production-daily.sh` laeuft taeglich als Cron-Job unter `trigowikisvc` auf `brisen`.
   - `backup_trigowiki_new_wiki.bat` laeuft als geplanter Task auf `trigonet-ps-01` unter `sa-pstrigonet` und kopiert den neuesten Snapshot nach `\\trigonet.local\DFS\SQL-Backup_trigonet.local\BRISEN\Trigowiki_Backup\trigowiki-backup`.
   - Externe Kopie ist damit sichergestellt.

3. Direkte Backend-Ports sollten spaeter reduziert werden.
   - `8081` fuer das Wiki-Backend und `8080` fuer Appsmith sind noch direkt erreichbar.
   - Ziel bleibt, Backends nur ueber OpenResty oder lokal/interne Docker-Netze erreichbar zu machen.

4. Alte Produktionsdienste erst nach Beobachtungszeit entfernen.
   - `mediawiki_wiki`, `mediawiki_mysql` und `11f951d24998_elasticsearch` bleiben vorerst fuer Rollback bestehen.
   - Die neuen Container heissen `mediawiki_wiki_production`, `mediawiki_mysql_production` und `opensearch_production`.
   - Beim Recreate des Containers einfach `bash /srv/mediawiki-production/script/start-wiki-production.sh` ausfuehren. Das Skript setzt Service-Namen und bindet alle Volumes korrekt ein.

5. Nach Host-/Container-Restarts immer kurze Produktionschecks ausfuehren.
   - `curl -sG 'http://trigowiki.trigonet.local/api.php' --data-urlencode 'action=query' --data-urlencode 'list=search' --data-urlencode 'srsearch=Hauptseite' --data-urlencode 'format=json'`
   - `docker exec mediawiki_wiki_production curl -sS --max-time 3 http://opensearch_production:9200/_cluster/health`
   - Erwartung: Such-API liefert Treffer, OpenSearch-Health ist `green`.

## Produktionsbackup

Das Repo enthaelt zwei Backup-Bausteine:

- `script/backup-production-daily.sh`: taegliches Betriebsbackup mit Datenbankdump, Uploads, `config`, `config-lts` und `Ressourcen`; Standardziel `/srv/mediawiki-production/backup/daily/<timestamp>`, Retention 2 Tage.
- `script/snapshot-production.sh`: groesserer manueller Produktionssnapshot-Baustein fuer besondere Wartungsfenster; Standardziel `/srv/mediawiki/backup/snapshots/<timestamp>`.

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

## Aktueller Produktionsstand

Port `80` ist auf OpenResty umgestellt. Rollback-Befehl:

```bash
docker rm -f trigowiki_openresty
docker start mediawiki_wiki
```

Naechste Reihenfolge:

1. Backup laeuft: Cron auf `brisen` plus Windows-Fetch auf DFS-Share.
2. Produktion einige Tage beobachten: OpenResty-Logs, MediaWiki-Logs, Suche, Uploads, Appsmith.
3. Danach direkte Backend-Ports reduzieren und alte Container/Images geordnet entfernen.
