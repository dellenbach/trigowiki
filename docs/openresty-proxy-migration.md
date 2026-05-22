# OpenResty Proxy Migration

Stand: 2026-05-22

## Kurzfazit

Die Zielarchitektur ist sinnvoll: Appsmith, Trigowiki und Reverse Proxy werden getrennt betrieben. Das reduziert Kopplung, macht den Wiki-Container einfacher und erlaubt spaeter saubere Updates von Proxy, Wiki und Appsmith unabhaengig voneinander.

Der Cutover auf OpenResty ist erfolgt. Produktionssnapshot, Restore-Test und ausreichend freier Speicher wurden vorher nachgewiesen; offen bleibt der Regelbetrieb fuer Backups und das spaetere Reduzieren direkter Backend-Ports.

## Ist-Zustand

- `trigowiki_openresty` publiziert `0.0.0.0:80 -> 80/tcp`.
- Der alte Container `mediawiki_wiki` ist gestoppt und bleibt als Rollback-Punkt vorhanden.
- `appsmith` publiziert `0.0.0.0:8080 -> 80/tcp` und `0.0.0.0:8443 -> 443/tcp`.
- `mediawiki_wiki_staging` publiziert `0.0.0.0:8081 -> 80/tcp`.
- `/srv/openresty` existiert auf `brisen` und enthaelt die produktive OpenResty-Konfiguration.
- `trigowiki_openresty_test` wurde nach erfolgreichem Cutover entfernt.

## Zielbild

- OpenResty ist der einzige oeffentliche HTTP/HTTPS Entry-Point.
- OpenResty hoert auf Port `80` und spaeter optional `443`.
- Neues Trigowiki laeuft in eigenem Container, zum Beispiel intern auf `trigowiki_new:80` oder hostseitig nur auf `127.0.0.1:8082`.
- Appsmith laeuft weiter in eigenem Container, bevorzugt ohne oeffentliche Host-Bindings oder nur auf `127.0.0.1:8080`.
- OpenResty, Appsmith und Trigowiki teilen ein dediziertes Proxy-Netzwerk, zum Beispiel `trigowiki_proxy`.
- OpenResty-Konfiguration liegt unter `/srv/openresty/config`.
- Runtime-/Log-/Cache-Daten liegen unter `/srv/openresty/logs` und `/srv/openresty/cache`.
- Host-Service-User `openrestysvc` besitzt `/srv/openresty` und fuehrt Deploy-/Restart-Kommandos aus.

## Empfehlung zur Port-Strategie

Best practice ist nicht, alle Backends oeffentlich auf `0.0.0.0` zu publizieren. Besser:

- Oeffentlich: nur OpenResty `0.0.0.0:80` und optional `0.0.0.0:443`.
- Wiki Backend: Docker-intern per Containername oder hostseitig `127.0.0.1:8082`.
- Appsmith Backend: Docker-intern per Containername oder hostseitig `127.0.0.1:8080`.
- Staging bleibt vorerst auf `8081`, bis Produktion umgestellt ist.

Wenn Appsmith weiterhin direkt erreichbar bleiben muss, kann `8080` temporaer bleiben. Als Ziel sollte der direkte Zugriff aber entfallen, damit der Proxy alle Header, WebSocket- und URL-Regeln kontrolliert.

## Service-User

Anlegen als Admin-Aufgabe:

```bash
sudo useradd --system --home /srv/openresty --create-home --shell /usr/sbin/nologin openrestysvc
sudo usermod -aG docker openrestysvc
sudo install -d -o openrestysvc -g openrestysvc /srv/openresty/config /srv/openresty/logs /srv/openresty/cache
```

Hinweis: Port `80` wird bei Docker-Publishing durch den Docker-Daemon gebunden. Der Host-User `openrestysvc` kann den Container verwalten, wenn er in der Docker-Gruppe ist. Innerhalb des Containers sollte OpenResty Worker-Prozesse unprivilegiert laufen lassen; der Container selbst braucht fuer `80:80` nicht zwingend als Host-root gestartet zu werden, weil Docker das Port-Binding uebernimmt.

Aktueller Zwischenstand: `openrestysvc` ist auf `brisen` angelegt und Mitglied der Docker-Gruppe. `/srv/openresty`, `/srv/openresty/config`, `/srv/openresty/logs` und `/srv/openresty/cache` gehoeren `openrestysvc:openrestysvc`; Schreibrechte wurden mit UID/GID `999:997` erfolgreich getestet.

## OpenResty-Konfiguration

Zielpfade auf dem Host:

```text
/srv/openresty/config/nginx.conf
/srv/openresty/config/conf.d/trigowiki.conf
/srv/openresty/logs/
/srv/openresty/cache/
```

Das Repo enthaelt dafuer:

```text
config/openresty/nginx.conf.template
script/prepare-openresty.sh
```

Der Testlauf generiert daraus `/srv/openresty/config/nginx.conf`. Auf dem aktuellen Docker-Host muss die Docker-Bridge-IP explizit als `HOST_GATEWAY` gesetzt werden, da `host-gateway` nicht unterstuetzt wird.

Produktiv zeigt die Konfiguration aktuell auf:

```text
trigowiki_backend -> host.docker.internal:8081
appsmith_backend  -> host.docker.internal:8080
```

Routing-Regeln:

- `trigowiki.trigonet.local` -> neues Trigowiki.
- `appsmith.trigonet.local` -> Appsmith.
- Falls Appsmith weiterhin unter Pfaden des Wiki-Hosts erreichbar sein muss, werden die existierenden Pfadregeln aus `config/nginx/nginx.conf` in OpenResty uebernommen:
  - `/app`, `/app/`, `/applications`, `/api/`, `/v1/`, `/oauth2/`, `/login/`, `/logout/`, `/signup/`, `/static/`, `/assets/`, `/scripts/`, `/health-check/`, `/socket.io/`, `/ws`.
- WebSocket-Header fuer Appsmith muessen erhalten bleiben:
  - `Upgrade`
  - `Connection`
  - `X-Forwarded-For`
  - `X-Forwarded-Proto`
  - `Host`

## Migrationsplan

### Phase 0: Voraussetzungen

1. Speicherplatz auf `brisen` erhoehen oder bereinigen. Ziel: mindestens 10 bis 15 GB frei.
2. Produktionssnapshot mit `script/snapshot-production.sh` erstellen.
3. Restore-Test aus dem Snapshot durchfuehren.
4. DNS/Hosts klaeren:
   - `trigowiki.trigonet.local`
   - `appsmith.trigonet.local`
5. Wartungsfenster definieren.

### Phase 1: OpenResty parallel vorbereiten

1. `openrestysvc` und `/srv/openresty` anlegen.
2. Docker-Netzwerk anlegen:

```bash
docker network create trigowiki_proxy
```

3. Appsmith zusaetzlich an `trigowiki_proxy` haengen:

```bash
docker network connect trigowiki_proxy appsmith
```

4. Neues Trigowiki zunaechst parallel auf internem Port starten, nicht auf Port `80`.
5. OpenResty testweise auf `8088` starten:

```bash
HOST_GATEWAY=$(ip -4 addr show docker0 | awk '/inet / { sub(/\/.*/, "", $2); print $2; exit }')
OPENRESTY_ROOT=/srv/openresty \
OPENRESTY_TEST_PORT=8088 \
HOST_GATEWAY=$HOST_GATEWAY \
WIKI_BACKEND=host.docker.internal:80 \
APPSMITH_BACKEND=host.docker.internal:8080 \
./script/prepare-openresty.sh
```

6. Syntax pruefen:

```bash
docker exec trigowiki_openresty_test openresty -t
```

7. Smoke-Test mit Host-Headern:

```bash
curl -H 'Host: trigowiki.trigonet.local' http://localhost:8088/
curl -H 'Host: appsmith.trigonet.local' http://localhost:8088/
```

Aktueller Produktionsstand:

- OpenResty-Konfiguration: Syntax `ok`.
- `Host: trigowiki.trigonet.local` `/`: HTTP `200`.
- `Host: trigowiki.trigonet.local` Suche `postgres`: HTTP `200`.
- `Host: trigowiki.trigonet.local` Suche `gres` mit `go=Seite`: HTTP `200`.
- `Host: trigowiki.trigonet.local` Bildauslieferung: HTTP `200`.
- `Host: trigowiki.trigonet.local` `/app`: HTTP `200`.
- `Host: appsmith.trigonet.local` `/`: HTTP `200`.

### Phase 2: Neues Wiki produktionsnah validieren

1. Neues Trigowiki gegen Produktionsdatenbank-Kopie oder im finalen Wartungsfenster gegen Produktionsdatenbank starten.
2. `MEDIAWIKI_SERVER` auf die finale URL setzen.
3. Uploads, Suche, Login, Spezialseiten, Appsmith-Links und Breadcrumbs testen.
4. OpenSearch/CirrusSearch Reindex vollstaendig ausfuehren.
5. Logs pruefen:

```bash
docker logs trigowiki_openresty_test --tail 200
docker logs <new-wiki-container> --tail 200
```

### Phase 3: Cutover im Wartungsfenster

Status: erledigt am 2026-05-22. Es wurde kein neuer Snapshot erstellt, weil seit Snapshot `20260522T141847Z` keine Produktionsaenderungen mehr erfolgt waren.

1. Schreibzugriffe stoppen oder Wiki read-only setzen.
2. Finalen Produktionssnapshot erstellen.
3. Alten Wiki-Container stoppen, damit Port `80` frei wird:

```bash
docker stop mediawiki_wiki
```

4. OpenResty von Testport `8088` auf Produktionsport `80` umstellen:

```bash
docker rm -f trigowiki_openresty_test
docker run -d \
  --name trigowiki_openresty \
  --restart always \
  --network trigowiki_proxy \
  -p 80:80 \
  -v /srv/openresty/config/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro \
  -v /srv/openresty/logs:/usr/local/openresty/nginx/logs \
  -v /srv/openresty/cache:/var/cache/nginx \
  openresty/openresty:alpine
```

5. Smoke-Tests:

```bash
curl -I http://trigowiki.trigonet.local/
curl -I http://appsmith.trigonet.local/
curl -I http://trigowiki.trigonet.local/index.php?search=postgres
```

6. Browser-Test:
   - Login
   - Suche
   - Bildanzeige
   - Datei-Upload
   - Appsmith Startseite
   - Appsmith WebSocket-Funktionen

### Phase 4: Nacharbeiten

1. Direkte Host-Port-Bindings von Appsmith entfernen oder auf `127.0.0.1` begrenzen.
2. Alte Wiki-Nginx-/Routing-Aufgaben aus dem Wiki-Container entfernen.
3. Monitoring/Logrotation fuer `/srv/openresty/logs` einrichten.
4. Rollback-Zeitfenster definieren, danach alte Container/Images geordnet entfernen.

## Rollback

Wenn OpenResty oder das neue Wiki im Wartungsfenster scheitert:

1. OpenResty stoppen:

```bash
docker rm -f trigowiki_openresty
```

2. Alten Wiki-Container wieder starten:

```bash
docker start mediawiki_wiki
```

3. Pruefen:

```bash
curl -I http://trigowiki.trigonet.local/
curl -I http://appsmith.trigonet.local/
```

4. Wenn Datenbank bereits migriert wurde und nicht abwaertskompatibel ist: Restore aus dem finalen Produktionssnapshot.

## Risiken

- Appsmith nutzt WebSockets; Proxy-Header und Timeouts muessen korrekt bleiben.
- MediaWiki erzeugt absolute URLs anhand von `$wgServer`; diese Variable muss zum externen Proxy-Host passen.
- Wenn Backends weiter oeffentlich publiziert sind, umgehen Benutzer moeglicherweise den Proxy.
- Port-80-Cutover ist der kritische Moment, weil aktuell der alte Wiki-Container diesen Port besitzt.
- Bei Datenbankmigration ist Rollback nur mit Snapshot realistisch.

## Entscheidung

Architektur: empfohlen.

Status: produktiv auf Port `80` aktiv. Rollback bleibt kurzfristig moeglich mit:

```bash
docker rm -f trigowiki_openresty
docker start mediawiki_wiki
```
