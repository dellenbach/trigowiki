#!/usr/bin/env bash
# setup-new-server.sh
#
# Ersteinrichtung von Trigowiki auf einem neuen Server.
#
# Was dieses Script tut:
#   1. Service-User trigowikisvc anlegen (falls noch nicht vorhanden)
#   2. Verzeichnisstruktur unter PROD_ROOT erstellen
#   3. Repo-Dateien deployen (config, scripts, ressourcen)
#   4. .env anlegen (von .env.example), Werte muessen noch eingetragen werden
#   5. Netzwerk und Volumes anlegen, Stack mit docker compose starten
#   6. Optional: DB-Dump importieren
#   7. Smoketest
#
# Danach (manuell):
#   - Uploads von Produktivserver kopieren:  rsync -a <prod>:/srv/mediawiki-production/images/ /srv/mediawiki-production/images/
#   - Extensions kopieren:                  rsync -a <prod>:/srv/mediawiki-production/extensions-lts/ /srv/mediawiki-production/extensions-lts/
#   - Ressourcen kopieren:                  rsync -a <prod>:/srv/mediawiki-production/Ressourcen/ /srv/mediawiki-production/Ressourcen/
#   - DB-Dump importieren:                  bash /srv/mediawiki-production/script/restore-from-backup.sh /pfad/zum/dump.sql
#   - Suchindex aufbauen:                   docker exec mediawiki_wiki_production bash /srv/mediawiki-production/script/reindex-search.sh
#   - OpenResty starten:                    bash /srv/mediawiki-production/script/prepare-openresty.sh
#   - Backup-Cron einrichten:               bash /srv/mediawiki-production/script/setup-cron-trigowikisvc.sh
#
# Voraussetzungen: docker, docker compose, git, rsync

set -euo pipefail

PROD_ROOT=${PROD_ROOT:-/srv/mediawiki-production}
SERVICE_USER=${SERVICE_USER:-trigowikisvc}
REPO_ROOT=$(cd "$(dirname "$0")/.." && pwd)
ENV_FILE="${PROD_ROOT}/.env"
COMPOSE_FILE="${REPO_ROOT}/docker-compose.yml"

# --- Root-Check ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Dieses Script muss als root oder via sudo ausgefuehrt werden." >&2
    exit 1
fi

echo "=== Trigowiki Neuinstallation ==="
echo "  Prod-Root : $PROD_ROOT"
echo "  User      : $SERVICE_USER"
echo "  Repo      : $REPO_ROOT"
echo ""

# --- 1. Service-User anlegen ---
echo "[1/7] Service-User $SERVICE_USER..."
if ! id "$SERVICE_USER" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --home-dir "$PROD_ROOT" \
        --shell /bin/bash \
        --groups docker \
        "$SERVICE_USER"
    echo "  Benutzer angelegt."
else
    usermod --append --groups docker "$SERVICE_USER" 2>/dev/null || true
    echo "  Benutzer existiert bereits."
fi

# --- 2. Verzeichnisstruktur ---
echo "[2/7] Verzeichnisse anlegen..."
mkdir -p \
    "${PROD_ROOT}/backup/daily" \
    "${PROD_ROOT}/config-lts" \
    "${PROD_ROOT}/extensions-lts" \
    "${PROD_ROOT}/images" \
    "${PROD_ROOT}/Ressourcen" \
    "${PROD_ROOT}/script"

chown -R "${SERVICE_USER}:${SERVICE_USER}" "$PROD_ROOT"
chmod 750 "$PROD_ROOT"

# --- 3. Repo-Dateien deployen ---
echo "[3/7] Konfiguration und Scripts deployen..."
cp -af "${REPO_ROOT}/config/mediawiki-lts/." "${PROD_ROOT}/config-lts/"
cp -af "${REPO_ROOT}/script/." "${PROD_ROOT}/script/"
cp -af "${REPO_ROOT}/Ressourcen/." "${PROD_ROOT}/Ressourcen/"
chmod -R a+rX "${PROD_ROOT}/Ressourcen"
find "${PROD_ROOT}/script" -name '*.sh' -exec chmod 750 {} +
chown -R "${SERVICE_USER}:${SERVICE_USER}" \
    "${PROD_ROOT}/config-lts" \
    "${PROD_ROOT}/script" \
    "${PROD_ROOT}/Ressourcen"

# --- 4. .env erstellen (wenn noch nicht vorhanden) ---
echo "[4/7] Secrets-Datei..."
if [ ! -f "${ENV_FILE}" ]; then
    cp "${REPO_ROOT}/.env.example" "${ENV_FILE}"
    chmod 600 "${ENV_FILE}"
    chown "${SERVICE_USER}:${SERVICE_USER}" "${ENV_FILE}"
    echo ""
    echo "  WICHTIG: ${ENV_FILE} wurde angelegt."
    echo "  Bitte jetzt die Secrets eintragen (MEDIAWIKI_DB_PASSWORD, MEDIAWIKI_SECRET_KEY):"
    echo "    sudo -u ${SERVICE_USER} nano ${ENV_FILE}"
    echo ""
    read -r -p "  Druecke ENTER, sobald die Secrets gesetzt sind..."
else
    echo "  ${ENV_FILE} existiert bereits."
fi

# Pruefen ob Platzhalter noch drin sind
if grep -qE '^(MEDIAWIKI_DB_PASSWORD|MEDIAWIKI_SECRET_KEY)=change-me' "${ENV_FILE}"; then
    echo "FEHLER: ${ENV_FILE} enthaelt noch Platzhalter-Werte. Bitte aendern." >&2
    exit 1
fi

# --- 5. Docker-Stack starten ---
echo "[5/7] Docker-Stack starten..."
export PROD_ROOT
docker compose --file "${COMPOSE_FILE}" --env-file "${ENV_FILE}" up -d

echo "  Warte 20 Sekunden auf DB und OpenSearch..."
sleep 20

docker ps --filter "name=mediawiki_wiki_production" \
          --filter "name=mediawiki_mysql_production" \
          --filter "name=opensearch_production" \
          --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

# --- 6. Optionaler DB-Import ---
echo ""
echo "[6/7] DB-Import..."
echo "  Wenn du einen Dump einspielen willst, jetzt ausfuehren:"
echo "    bash ${PROD_ROOT}/script/restore-from-backup.sh /pfad/zum/wikidb.sql"
echo "  (Oder ENTER druecken um zu ueberspringen)"
read -r -p "  Pfad zum Dump (leer = ueberspringen): " DUMP_PATH
if [ -n "${DUMP_PATH}" ] && [ -f "${DUMP_PATH}" ]; then
    bash "${PROD_ROOT}/script/restore-from-backup.sh" "${DUMP_PATH}"
else
    echo "  Kein Dump angegeben oder Datei nicht gefunden; uebersprungen."
fi

# --- 7. Smoketest ---
echo "[7/7] Smoketest..."
sleep 5
HTTP=$(curl -s -o /dev/null -w "%{http_code}" \
    "http://localhost:8081/Hauptseite" 2>/dev/null || echo "000")
echo "  HTTP Hauptseite (localhost:8081): ${HTTP}"

echo ""
echo "=== Fertig ==="
echo ""
echo "Naechste Schritte:"
echo "  1. Uploads/Ressourcen/Extensions vom Produktivserver kopieren (wenn kein Dump)"
echo "  2. Suchindex aufbauen:"
echo "       docker exec mediawiki_wiki_production bash /srv/mediawiki-production/script/reindex-search.sh"
echo "  3. OpenResty (Port 80) einrichten:"
echo "       bash /srv/mediawiki-production/script/prepare-openresty.sh"
echo "  4. Backup-Cron einrichten:"
echo "       sudo bash /srv/mediawiki-production/script/setup-cron-trigowikisvc.sh"
