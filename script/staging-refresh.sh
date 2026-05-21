#!/bin/bash
set -euo pipefail

REPO_ROOT=${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
PROD_ROOT=${PROD_ROOT:-/srv/mediawiki}
STAGING_SERVICE_USER=${STAGING_SERVICE_USER:-trigowikisvc}
STAGING_ROOT=${STAGING_ROOT:-/srv/mediawiki-staging}
STAGING_HTTP_PORT=${STAGING_HTTP_PORT:-8081}
STAGING_MEDIAWIKI_SERVER=${STAGING_MEDIAWIKI_SERVER:-http://brisen:${STAGING_HTTP_PORT}}

PROD_DB_CONTAINER=${PROD_DB_CONTAINER:-mediawiki_mysql}
STAGING_DB_CONTAINER=${STAGING_DB_CONTAINER:-mediawiki_mysql_staging}
STAGING_WIKI_CONTAINER=${STAGING_WIKI_CONTAINER:-mediawiki_wiki_staging}
STAGING_ES_CONTAINER=${STAGING_ES_CONTAINER:-elasticsearch_staging}
STAGING_NETWORK=${STAGING_NETWORK:-trigowiki_staging}
STAGING_WIKI_IMAGE=${STAGING_WIKI_IMAGE:-trigowiki}

STAGING_DB_ROOT_PASSWORD=${STAGING_DB_ROOT_PASSWORD:-staging-root-change-me}
STAGING_MEDIAWIKI_SECRET_KEY=${STAGING_MEDIAWIKI_SECRET_KEY:-staging-secret-change-me}
RUN_STAGING_REINDEX=${RUN_STAGING_REINDEX:-1}
RESET_STAGING_VOLUMES=${RESET_STAGING_VOLUMES:-1}
BUILD_STAGING_IMAGE=${BUILD_STAGING_IMAGE:-1}

current_user=$(id -un)
if [ "${current_user}" != "${STAGING_SERVICE_USER}" ]; then
    echo "Warning: staging refresh runs as ${current_user}; target service user is ${STAGING_SERVICE_USER}." >&2
fi

echo "Preparing staging directories in ${STAGING_ROOT}"
mkdir -p \
    "${STAGING_ROOT}/backup" \
    "${STAGING_ROOT}/config" \
    "${STAGING_ROOT}/images" \
    "${STAGING_ROOT}/Ressourcen" \
    "${STAGING_ROOT}/extensions" \
    "${STAGING_ROOT}/skins" \
    "${STAGING_ROOT}/includes"

echo "Copying repository config to staging"
cp "${REPO_ROOT}"/config/mediawiki/*.php "${STAGING_ROOT}/config/"
cp "${REPO_ROOT}/config/nginx/nginx.conf" "${STAGING_ROOT}/config/nginx.conf"
rsync -a --delete "${REPO_ROOT}/Ressourcen/" "${STAGING_ROOT}/Ressourcen/"
chmod -R a+rX "${STAGING_ROOT}/Ressourcen"

echo "Copying production file data to staging"
rsync -a --delete "${PROD_ROOT}/images/" "${STAGING_ROOT}/images/"
rsync -a --delete "${PROD_ROOT}/extensions/" "${STAGING_ROOT}/extensions/"
rsync -a --delete "${PROD_ROOT}/skins/Vector/" "${STAGING_ROOT}/skins/Vector/"
rsync -a --delete "${PROD_ROOT}/includes/" "${STAGING_ROOT}/includes/"

dump_file="${STAGING_ROOT}/backup/wikidb-staging.sql"
echo "Dumping production database to ${dump_file}"
docker exec "${PROD_DB_CONTAINER}" sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" wikidb' > "${dump_file}"

echo "Creating staging Docker network"
docker network inspect "${STAGING_NETWORK}" >/dev/null 2>&1 || docker network create "${STAGING_NETWORK}" >/dev/null

if [ "${BUILD_STAGING_IMAGE}" = "1" ]; then
    echo "Building staging wiki image ${STAGING_WIKI_IMAGE}"
    docker build -t "${STAGING_WIKI_IMAGE}" "${REPO_ROOT}"
fi

echo "Replacing old staging containers"
docker rm -f "${STAGING_WIKI_CONTAINER}" "${STAGING_DB_CONTAINER}" "${STAGING_ES_CONTAINER}" >/dev/null 2>&1 || true
if [ "${RESET_STAGING_VOLUMES}" = "1" ]; then
    echo "Removing old staging volumes"
    docker volume rm -f mediawiki_mysql_staging esdata_staging >/dev/null 2>&1 || true
fi
docker volume create mediawiki_mysql_staging >/dev/null
docker volume create esdata_staging >/dev/null

echo "Starting staging database"
docker run -d \
    --name "${STAGING_DB_CONTAINER}" \
    --network "${STAGING_NETWORK}" \
    -e MYSQL_DATABASE=wikidb \
    -e MYSQL_ROOT_PASSWORD="${STAGING_DB_ROOT_PASSWORD}" \
    -v mediawiki_mysql_staging:/var/lib/mysql \
    -v "${STAGING_ROOT}/backup:/srv/mediawiki/backup" \
    mysql:5.7 >/dev/null

echo "Waiting for staging database"
for attempt in $(seq 1 60); do
    if docker exec "${STAGING_DB_CONTAINER}" sh -c 'mysql -uroot -p"$MYSQL_ROOT_PASSWORD" -e "select 1" >/dev/null' >/dev/null 2>&1; then
        break
    fi
    if [ "${attempt}" -eq 60 ]; then
        echo "Staging database did not become ready" >&2
        exit 1
    fi
    sleep 2
done

echo "Importing production dump into staging database"
docker exec -i "${STAGING_DB_CONTAINER}" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" wikidb' < "${dump_file}"

echo "Starting staging Elasticsearch"
docker run -d \
    --name "${STAGING_ES_CONTAINER}" \
    --network "${STAGING_NETWORK}" \
    -v esdata_staging:/usr/share/elasticsearch/data \
    elasticsearch:5.4 >/dev/null

echo "Waiting for staging Elasticsearch"
for attempt in $(seq 1 60); do
    if docker exec "${STAGING_ES_CONTAINER}" curl -fsS http://localhost:9200/_cluster/health >/dev/null 2>&1; then
        break
    fi
    if [ "${attempt}" -eq 60 ]; then
        echo "Staging Elasticsearch did not become ready" >&2
        exit 1
    fi
    sleep 2
done

echo "Starting staging wiki on port ${STAGING_HTTP_PORT}"
docker run -d \
    --name "${STAGING_WIKI_CONTAINER}" \
    --network "${STAGING_NETWORK}" \
    -p "${STAGING_HTTP_PORT}:8080" \
    -e MEDIAWIKI_SERVER="${STAGING_MEDIAWIKI_SERVER}" \
    -e MEDIAWIKI_SITENAME="Trigowiki Staging" \
    -e MEDIAWIKI_LANGUAGE_CODE=de \
    -e MEDIAWIKI_SECRET_KEY="${STAGING_MEDIAWIKI_SECRET_KEY}" \
    -e MEDIAWIKI_DB_TYPE=mysql \
    -e MEDIAWIKI_DB_HOST="${STAGING_DB_CONTAINER}" \
    -e MEDIAWIKI_DB_PORT=3306 \
    -e MEDIAWIKI_DB_NAME=wikidb \
    -e MEDIAWIKI_DB_USER=root \
    -e MEDIAWIKI_DB_TABLE_OPTIONS="ENGINE=InnoDB, DEFAULT CHARSET=binary" \
    -e MEDIAWIKI_DB_PASSWORD="${STAGING_DB_ROOT_PASSWORD}" \
    -e MEDIAWIKI_SEARCH_HOST="${STAGING_ES_CONTAINER}" \
    -e MEDIAWIKI_ENABLE_UPLOADS=1 \
    -e MEDIAWIKI_EXTENSION_VISUAL_EDITOR_ENABLED=1 \
    -e MEDIAWIKI_DEFAULT_SKIN=vector \
    -v "${STAGING_ROOT}/config/LocalSettings.php:/var/www/mediawiki/LocalSettings.php" \
    -v "${STAGING_ROOT}/config/ExtraLocalSettings.php:/var/www/mediawiki/ExtraLocalSettings.php" \
    -v "${STAGING_ROOT}/config/Permissions.php:/var/www/mediawiki/Permissions.php" \
    -v "${STAGING_ROOT}/config/Extensions.php:/var/www/mediawiki/Extensions.php" \
    -v "${STAGING_ROOT}/config/UploadSettings.php:/var/www/mediawiki/UploadSettings.php" \
    -v "${STAGING_ROOT}/config/EmbeddingSettings.php:/var/www/mediawiki/EmbeddingSettings.php" \
    -v "${STAGING_ROOT}/config/CirrusSearchTuning.php:/var/www/mediawiki/CirrusSearchTuning.php" \
    -v "${STAGING_ROOT}/config/InfixTitleSearch.php:/var/www/mediawiki/InfixTitleSearch.php" \
    -v "${STAGING_ROOT}/config/nginx.conf:/etc/nginx/nginx.conf" \
    -v "${STAGING_ROOT}/images:/var/www/mediawiki/images" \
    -v "${STAGING_ROOT}/Ressourcen:/var/www/mediawiki/resources/trigowiki:ro" \
    -v "${STAGING_ROOT}/extensions:/var/www/mediawiki/extensions" \
    -v "${STAGING_ROOT}/skins/Vector:/var/www/mediawiki/skins/Vector" \
    -v "${STAGING_ROOT}/includes:/var/www/mediawiki/includes" \
    "${STAGING_WIKI_IMAGE}" >/dev/null

echo "Waiting for staging wiki container"
sleep 10

echo "Running MediaWiki database update in staging"
docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/maintenance/update.php --quick

if [ "${RUN_STAGING_REINDEX}" = "1" ]; then
    echo "Rebuilding staging search index"
    docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php --reindexAndRemoveOk --indexIdentifier now
    docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php
    docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSuggesterIndex.php
    docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipLinks --indexOnSkip
    docker exec "${STAGING_WIKI_CONTAINER}" php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipParse
fi

echo "Staging migration completed: ${STAGING_MEDIAWIKI_SERVER}"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | awk 'NR == 1 || /_staging/'
