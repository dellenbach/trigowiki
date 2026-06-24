#!/usr/bin/env bash
# start-wiki-production.sh
#
# Startet (oder ersetzt) den Wiki-Produktionscontainer mediawiki_wiki_production.
# Verwendet stabile Docker-DNS-Namen fuer DB und Search statt Container-IPs.
#
# Verwendung:
#   sudo -u trigowikisvc bash /srv/mediawiki-production/script/start-wiki-production.sh
#
# Voraussetzung: /srv/mediawiki-production/.env.production muss existieren.
# Vorlage: .env.production.example im Repo

set -euo pipefail

ENV_FILE="/srv/mediawiki-production/.env.production"
if [ ! -f "$ENV_FILE" ]; then
    echo "FEHLER: $ENV_FILE nicht gefunden." >&2
    echo "Vorlage: script/.env.production.example im Repo" >&2
    exit 1
fi

# Secrets laden
# shellcheck disable=SC1090
. "$ENV_FILE"

: "${MEDIAWIKI_DB_PASSWORD:?MEDIAWIKI_DB_PASSWORD fehlt in $ENV_FILE}"
: "${MEDIAWIKI_SECRET_KEY:?MEDIAWIKI_SECRET_KEY fehlt in $ENV_FILE}"

OPTIONAL_ENV_VARS=(
    MEDIAWIKI_EMERGENCY_CONTACT
    MEDIAWIKI_PASSWORD_SENDER
    MEDIAWIKI_SMTP_HOST
    MEDIAWIKI_SMTP_PORT
    MEDIAWIKI_SMTP_AUTH
    MEDIAWIKI_SMTP_SECURE
    MEDIAWIKI_SMTP_USERNAME
    MEDIAWIKI_SMTP_PASSWORD
)

OPTIONAL_ENV_ARGS=()
for var_name in "${OPTIONAL_ENV_VARS[@]}"; do
    var_value="${!var_name:-}"
    if [ -n "$var_value" ]; then
        OPTIONAL_ENV_ARGS+=( -e "${var_name}=${var_value}" )
    fi
done

CONTAINER_NAME="mediawiki_wiki_production"
IMAGE="mediawiki:1.45.3"
NETWORK="trigowiki_production"
BASE="/srv/mediawiki-production"

echo "Stoppe und entferne $CONTAINER_NAME (falls vorhanden)..."
docker stop "$CONTAINER_NAME" 2>/dev/null || true
docker rm   "$CONTAINER_NAME" 2>/dev/null || true

echo "Starte $CONTAINER_NAME mit Service-Namen (keine statischen IPs)..."
docker run -d \
    --name "$CONTAINER_NAME" \
    --network "$NETWORK" \
    --restart unless-stopped \
    -p 8081:80 \
    -e MEDIAWIKI_DB_TYPE=mysql \
    -e MEDIAWIKI_DB_HOST=mediawiki_mysql_production \
    -e MEDIAWIKI_DB_PORT=3306 \
    -e MEDIAWIKI_DB_NAME=wikidb \
    -e MEDIAWIKI_DB_USER=root \
    -e "MEDIAWIKI_DB_TABLE_OPTIONS=ENGINE=InnoDB, DEFAULT CHARSET=binary" \
    -e "MEDIAWIKI_DB_PASSWORD=${MEDIAWIKI_DB_PASSWORD}" \
    -e "MEDIAWIKI_SECRET_KEY=${MEDIAWIKI_SECRET_KEY}" \
    -e MEDIAWIKI_SEARCH_HOST=opensearch_production \
    -e MEDIAWIKI_SEARCH_ENABLED=1 \
    -e MEDIAWIKI_SERVER=http://trigowiki.trigonet.local \
    -e MEDIAWIKI_SITENAME=Trigowiki \
    -e MEDIAWIKI_LANGUAGE_CODE=de \
    -e MEDIAWIKI_DEFAULT_SKIN=vector \
    -e MEDIAWIKI_ENABLE_UPLOADS=1 \
    "${OPTIONAL_ENV_ARGS[@]}" \
    -v "${BASE}/config-lts/LocalSettings.php:/var/www/html/LocalSettings.php" \
    -v "${BASE}/config-lts/SearchSettings.php:/var/www/html/SearchSettings.php" \
    -v "${BASE}/config-lts/RecentBreadcrumbs.php:/var/www/html/RecentBreadcrumbs.php" \
    -v "${BASE}/config-lts/InfixTitleSearch.php:/var/www/html/InfixTitleSearch.php" \
    -v "${BASE}/extensions-lts/Elastica:/var/www/html/extensions/Elastica" \
    -v "${BASE}/extensions-lts/CirrusSearch:/var/www/html/extensions/CirrusSearch" \
    -v "${BASE}/extensions-lts/AdvancedSearch:/var/www/html/extensions/AdvancedSearch" \
    -v "${BASE}/extensions-lts/TimedMediaHandler:/var/www/html/extensions/TimedMediaHandler" \
    -v "${BASE}/extensions-lts/Interwiki:/var/www/html/extensions/Interwiki" \
    -v "${BASE}/images:/var/www/html/images" \
    -v "${BASE}/Ressourcen:/var/www/html/resources/trigowiki" \
    "$IMAGE"

echo "Container gestartet. Warte 5 Sekunden..."
sleep 5

docker ps --filter "name=${CONTAINER_NAME}" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "Pruefe Suchverbindung (OpenSearch)..."
if docker exec "$CONTAINER_NAME" curl -sS --max-time 5 \
        http://opensearch_production:9200/_cluster/health | grep -q '"status":"green"'; then
    echo "  OpenSearch: gruen"
else
    echo "  WARNUNG: OpenSearch nicht gruen. Suchindex ggf. neu aufbauen." >&2
fi

echo ""
echo "Pruefe Wiki-HTTP..."
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://trigowiki.trigonet.local/Hauptseite)
echo "  Hauptseite: $HTTP"

echo ""
echo "Fertig. Smoketest:"
echo "  curl -sG 'http://trigowiki.trigonet.local/api.php' \\"
echo "    --data-urlencode 'action=query' --data-urlencode 'list=search' \\"
echo "    --data-urlencode 'srsearch=Hauptseite' --data-urlencode 'format=json'"
