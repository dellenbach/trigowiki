# Staging-Migration

Stand: 2026-05-21

Ziel: Eine getrennte Trigowiki-Staging-Instanz auf `brisen` betreiben, um DB-/Config-/Upgrade-Migrationen zu testen, ohne die produktiven Container zu veraendern.

## Zielzustand

- Staging-Webport: `8081`
- Staging-Wiki: `mediawiki_wiki_staging`
- Staging-DB: `mediawiki_mysql_staging`
- Staging-Suche: `elasticsearch_staging`
- Staging-Netzwerk: `trigowiki_staging`
- Staging-Service-User: `trigowikisvc`
- Staging-Dateien: `/srv/mediawiki-staging`

Die produktive Umgebung bleibt lesend Quelle fuer Kopien:

- Datenbankdump aus `mediawiki_mysql`
- Uploads aus `/srv/mediawiki/images`
- produktive Erweiterungen aus `/srv/mediawiki/extensions`
- produktiver MediaWiki-Core aus `/srv/mediawiki/includes`
- Vector-Skin aus `/srv/mediawiki/skins/Vector`

Die Konfiguration kommt aus dem Repository und wird nach `/srv/mediawiki-staging/config` kopiert.

Repo-Ressourcen wie das Trigonet-Logo werden nach `STAGING_ROOT/Ressourcen` kopiert und im Wiki unter `/resources/trigowiki/` ausgeliefert.

## Ausfuehren auf brisen

Einmalig muss ein Admin den Service-User und das Zielverzeichnis vorbereiten:

```bash
cd /pfad/zum/trigowiki-repo
sudo STAGING_SERVICE_USER=trigowikisvc \
	STAGING_ROOT=/srv/mediawiki-staging \
	SSH_KEY_SOURCE_USER=del \
	./script/bootstrap-staging-service-user.sh
```

Danach sollte der SSH-Test funktionieren:

```bash
ssh trigowikisvc@brisen 'id; docker ps --format "{{.Names}}" | head'
```

Von Windows aus sollte der PowerShell-Wrapper verwendet werden. Er kopiert die benoetigten Repo-Dateien nach `brisen` und fuehrt dort ein eigenes Bash-Skript aus. Dadurch werden verschachtelte PowerShell-/SSH-/Bash-Quotes vermieden:

```powershell
$stagingDbRootValue = Read-Host -AsSecureString "Staging DB root password"
$stagingMediaWikiPrivateValue = Read-Host -AsSecureString "Staging MediaWiki secret key"
.\script\invoke-staging-refresh.ps1 `
	-StagingDbRootValue $stagingDbRootValue `
	-StagingMediaWikiPrivateValue $stagingMediaWikiPrivateValue
```

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

1. Staging-Verzeichnisse unter `STAGING_ROOT` anlegen, standardmaessig `/srv/mediawiki-staging`.
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

## Persistenz

Staging legt die relevanten Dateien bewusst ausserhalb des Wiki-Containers ab:

- `STAGING_ROOT/config`: MediaWiki- und Nginx-Konfiguration.
- `STAGING_ROOT/Ressourcen`: Repo-Ressourcen wie das Trigonet-Logo.
- `STAGING_ROOT/images`: Uploads aus Produktion.
- `STAGING_ROOT/extensions`, `STAGING_ROOT/skins/Vector`, `STAGING_ROOT/includes`: kopierter Altbestand fuer reproduzierbare Tests.
- `STAGING_ROOT/backup/wikidb-staging.sql`: SQL-Dump der Produktionsdatenbank fuer den Import.
- Docker-Volumes `mediawiki_mysql_staging` und `esdata_staging`: laufende Staging-Datenbank und Suchindex.

Der SQL-Dump wird bei jedem Refresh neu geschrieben. Suchindizes muessen nach einem frischen Elasticsearch-Volume oder nach einem MediaWiki-/Extension-Upgrade neu aufgebaut werden. Wenn nur Konfiguration oder statische Ressourcen geaendert werden und `esdata_staging` erhalten bleibt, kann `RUN_STAGING_REINDEX=0` genutzt werden.

## Zielbild Service-User

Fuer einen dauerhaften Staging- oder Produktionsbetrieb wird ein eigener Linux-Benutzer analog zum Appsmith-Service-User verwendet. Dieser Benutzer ist Besitzer von `/srv/mediawiki-staging` und Mitglied der Docker-Gruppe. Damit lassen sich Root-/`del`-Abhaengigkeiten reduzieren und Datei-Rechte fuer Uploads, Ressourcen und Backups sauber kontrollieren. Das Anlegen des Benutzers und Verzeichnisses ist ein einmaliger Admin-Schritt, weil `del` auf `brisen` keine passwortlosen sudo-Rechte hat.

## Hinweise fuer das LTS-Upgrade

Die erste Staging-Migration soll den aktuellen Altbestand reproduzieren. Danach kann eine zweite Staging-Variante mit neuer MediaWiki-LTS-Version gebaut werden. Suchindizes werden dabei neu aufgebaut, nicht aus Elasticsearch 5.4 migriert.