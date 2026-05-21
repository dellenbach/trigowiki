# Staging-Migration

Stand: 2026-05-21

Ziel: Eine getrennte Trigowiki-Staging-Instanz auf `brisen` betreiben, um DB-/Config-/Upgrade-Migrationen zu testen, ohne die produktiven Container zu veraendern.

## Zielzustand

- Staging-Webport: `8081`
- Staging-Wiki: `mediawiki_wiki_staging`
- Staging-DB: `mediawiki_mysql_staging`
- Staging-Suche: `elasticsearch_staging`
- Staging-Netzwerk: `trigowiki_staging`
- Staging-Dateien als Benutzer `del`: `/home/del/mediawiki-staging`

Die produktive Umgebung bleibt lesend Quelle fuer Kopien:

- Datenbankdump aus `mediawiki_mysql`
- Uploads aus `/srv/mediawiki/images`
- produktive Erweiterungen aus `/srv/mediawiki/extensions`
- produktiver MediaWiki-Core aus `/srv/mediawiki/includes`
- Vector-Skin aus `/srv/mediawiki/skins/Vector`

Die Konfiguration kommt aus dem Repository und wird nach `/home/del/mediawiki-staging/config` kopiert. Wenn das Skript mit einem Benutzer mit Schreibrechten unter `/srv` laeuft, kann `STAGING_ROOT=/srv/mediawiki-staging` gesetzt werden.

Repo-Ressourcen wie das Trigonet-Logo werden nach `STAGING_ROOT/Ressourcen` kopiert und im Wiki unter `/resources/trigowiki/` ausgeliefert.

## Ausfuehren auf brisen

Das Skript ist fuer Ausfuehrung auf dem Server gedacht:

```bash
cd /pfad/zum/trigowiki-repo
STAGING_HTTP_PORT=8081 ./script/staging-refresh.sh
```

Optional koennen die Staging-Secrets und die sichtbare URL explizit gesetzt werden:

```bash
STAGING_DB_ROOT_PASSWORD='...' \
STAGING_MEDIAWIKI_SECRET_KEY='...' \
STAGING_HTTP_PORT=8081 \
STAGING_MEDIAWIKI_SERVER='http://brisen:8081' \
./script/staging-refresh.sh
```

Standardmaessig werden die Staging-Volumes bei jedem Lauf neu erstellt, damit DB-Passwort und Dump sicher zusammenpassen. Fuer einen Lauf ohne Volume-Reset kann `RESET_STAGING_VOLUMES=0` gesetzt werden.

Danach ist Staging erreichbar unter:

```text
http://brisen:8081/
```

Der Suchindex wird standardmaessig neu aufgebaut, damit die Staging-Suche direkt nach dem Refresh funktioniert. Fuer einen schnelleren Lauf ohne Suchindex kann `RUN_STAGING_REINDEX=0` gesetzt werden:

```bash
RUN_STAGING_REINDEX=0 STAGING_HTTP_PORT=8081 ./script/staging-refresh.sh
```

## Was das Skript tut

1. Staging-Verzeichnisse unter `STAGING_ROOT` anlegen, standardmaessig `/home/del/mediawiki-staging`.
2. Repo-Konfiguration nach `STAGING_ROOT/config` kopieren.
3. Repo-Ressourcen sowie produktive Uploads, Erweiterungen, Vector-Skin und Core-Dateien nach Staging synchronisieren.
4. Produktive DB dumpen und in eine eigene Staging-DB importieren.
5. Eigene Staging-Container starten.
6. `maintenance/update.php --quick` im Staging-Wiki ausfuehren.
7. Optional den Suchindex im Staging neu aufbauen.

## Sicherheit

- Das Skript loescht und ersetzt nur Container mit Suffix `_staging`.
- Produktive Container werden nicht gestoppt.
- Produktive Daten werden gelesen, nicht veraendert.
- `STAGING_ROOT` kann bei jedem Lauf neu synchronisiert werden.

## Hinweise fuer das LTS-Upgrade

Die erste Staging-Migration soll den aktuellen Altbestand reproduzieren. Danach kann eine zweite Staging-Variante mit neuer MediaWiki-LTS-Version gebaut werden. Suchindizes werden dabei neu aufgebaut, nicht aus Elasticsearch 5.4 migriert.