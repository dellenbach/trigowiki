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
STAGING_MEDIAWIKI_PATH=${STAGING_MEDIAWIKI_PATH:-/var/www/mediawiki}

STAGING_DB_ROOT_PASSWORD=${STAGING_DB_ROOT_PASSWORD:-staging-root-change-me}
STAGING_MEDIAWIKI_SECRET_KEY=${STAGING_MEDIAWIKI_SECRET_KEY:-staging-secret-change-me}
RUN_STAGING_REINDEX=${RUN_STAGING_REINDEX:-1}
ALLOW_STAGING_REINDEX_FAILURE=${ALLOW_STAGING_REINDEX_FAILURE:-1}
RESET_STAGING_VOLUMES=${RESET_STAGING_VOLUMES:-1}
BUILD_STAGING_IMAGE=${BUILD_STAGING_IMAGE:-1}

run_staging_reindex() {
    echo "Rebuilding staging search index"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php" --reindexAndRemoveOk --indexIdentifier now
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/updateSuggesterIndex.php"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/forceSearchIndex.php" --skipLinks --indexOnSkip
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/forceSearchIndex.php" --skipParse
}

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
if docker ps --format '{{.Names}}' | grep -qx "${STAGING_WIKI_CONTAINER}"; then
    docker exec "${STAGING_WIKI_CONTAINER}" sh -c "image_dir=/var/www/mediawiki/images; if [ ! -d \"\$image_dir\" ] && [ -d /var/www/html/images ]; then image_dir=/var/www/html/images; fi; if [ ! -d \"\$image_dir\" ] && [ -d /images ]; then image_dir=/images; fi; find \"\$image_dir\" -mindepth 1 -maxdepth 1 -exec rm -rf {} +; chown '$(id -u):$(id -g)' \"\$image_dir\""
else
    docker run --rm -v "${STAGING_ROOT}/images:/images" --entrypoint sh busybox:1.36 -c 'find /images -mindepth 1 -maxdepth 1 -exec rm -rf {} +; chmod 0777 /images'
fi
rsync -a --no-owner --no-group --delete "${PROD_ROOT}/images/" "${STAGING_ROOT}/images/"
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
    -v "${STAGING_ROOT}/config/LocalSettings.php:${STAGING_MEDIAWIKI_PATH}/LocalSettings.php" \
    -v "${STAGING_ROOT}/config/ExtraLocalSettings.php:${STAGING_MEDIAWIKI_PATH}/ExtraLocalSettings.php" \
    -v "${STAGING_ROOT}/config/Permissions.php:${STAGING_MEDIAWIKI_PATH}/Permissions.php" \
    -v "${STAGING_ROOT}/config/Extensions.php:${STAGING_MEDIAWIKI_PATH}/Extensions.php" \
    -v "${STAGING_ROOT}/config/UploadSettings.php:${STAGING_MEDIAWIKI_PATH}/UploadSettings.php" \
    -v "${STAGING_ROOT}/config/EmbeddingSettings.php:${STAGING_MEDIAWIKI_PATH}/EmbeddingSettings.php" \
    -v "${STAGING_ROOT}/config/CirrusSearchTuning.php:${STAGING_MEDIAWIKI_PATH}/CirrusSearchTuning.php" \
    -v "${STAGING_ROOT}/config/InfixTitleSearch.php:${STAGING_MEDIAWIKI_PATH}/InfixTitleSearch.php" \
    -v "${STAGING_ROOT}/config/RecentBreadcrumbs.php:${STAGING_MEDIAWIKI_PATH}/RecentBreadcrumbs.php" \
    -v "${STAGING_ROOT}/config/nginx.conf:/etc/nginx/nginx.conf" \
    -v "${STAGING_ROOT}/images:${STAGING_MEDIAWIKI_PATH}/images" \
    -v "${STAGING_ROOT}/Ressourcen:${STAGING_MEDIAWIKI_PATH}/resources/trigowiki:ro" \
    -v "${STAGING_ROOT}/extensions:${STAGING_MEDIAWIKI_PATH}/extensions" \
    -v "${STAGING_ROOT}/skins/Vector:${STAGING_MEDIAWIKI_PATH}/skins/Vector" \
    -v "${STAGING_ROOT}/includes:${STAGING_MEDIAWIKI_PATH}/includes" \
    "${STAGING_WIKI_IMAGE}" >/dev/null

docker exec "${STAGING_WIKI_CONTAINER}" chown -R www-data:www-data "${STAGING_MEDIAWIKI_PATH}/images"

echo "Waiting for staging wiki container"
sleep 10

echo "Running MediaWiki database update in staging"
docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/maintenance/update.php" --quick

if [ "${RUN_STAGING_REINDEX}" = "1" ]; then
    if ! run_staging_reindex; then
        if [ "${ALLOW_STAGING_REINDEX_FAILURE}" = "1" ]; then
            echo "Warning: staging search reindex failed; continuing because ALLOW_STAGING_REINDEX_FAILURE=1." >&2
        else
            exit 1
        fi
    fi
fi

echo "Staging migration completed: ${STAGING_MEDIAWIKI_SERVER}"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | awk 'NR == 1 || /_staging/'
