#!/bin/bash
set -euo pipefail

REPO_ROOT=${REPO_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
PROD_ROOT=${PROD_ROOT:-/srv/mediawiki}
STAGING_SERVICE_USER=${STAGING_SERVICE_USER:-trigowikisvc}
STAGING_ROOT=${STAGING_ROOT:-/srv/mediawiki-staging}
STAGING_HTTP_PORT=${STAGING_HTTP_PORT:-8081}
STAGING_MEDIAWIKI_SERVER=${STAGING_MEDIAWIKI_SERVER:-http://brisen:${STAGING_HTTP_PORT}}

STAGING_DB_CONTAINER=${STAGING_DB_CONTAINER:-mediawiki_mysql_staging}
STAGING_WIKI_CONTAINER=${STAGING_WIKI_CONTAINER:-mediawiki_wiki_staging}
STAGING_ES_CONTAINER=${STAGING_ES_CONTAINER:-elasticsearch_staging}
STAGING_SEARCH_CONTAINER=${STAGING_SEARCH_CONTAINER:-elasticsearch_staging_lts}
STAGING_NETWORK=${STAGING_NETWORK:-trigowiki_staging}
STAGING_WIKI_IMAGE=${STAGING_WIKI_IMAGE:-mediawiki:1.43}
STAGING_SEARCH_IMAGE=${STAGING_SEARCH_IMAGE:-elasticsearch:7.10.2}
STAGING_CONTAINER_HTTP_PORT=${STAGING_CONTAINER_HTTP_PORT:-80}
STAGING_MEDIAWIKI_PATH=${STAGING_MEDIAWIKI_PATH:-/var/www/html}

STAGING_DB_ROOT_PASSWORD=${STAGING_DB_ROOT_PASSWORD:-staging-root-change-me}
STAGING_MEDIAWIKI_SECRET_KEY=${STAGING_MEDIAWIKI_SECRET_KEY:-staging-secret-change-me}
RESET_STAGING_VOLUMES=${RESET_STAGING_VOLUMES:-1}
IMPORT_PRODUCTION_DB=${IMPORT_PRODUCTION_DB:-1}
RUN_STAGING_UPDATE=${RUN_STAGING_UPDATE:-1}
ENABLE_MODERN_SEARCH=${ENABLE_MODERN_SEARCH:-0}
RUN_STAGING_REINDEX=${RUN_STAGING_REINDEX:-1}
STAGING_ELASTICA_BRANCH=${STAGING_ELASTICA_BRANCH:-REL1_43}
STAGING_CIRRUS_BRANCH=${STAGING_CIRRUS_BRANCH:-REL1_43}
STAGING_SEARCH_VOLUME=${STAGING_SEARCH_VOLUME:-esdata_lts_staging}

ensure_lts_extension() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3
    local target_name
    target_name=$(basename "${target_dir}")

    if [ ! -d "${target_dir}/.git" ]; then
        rm -rf "${target_dir}"
        docker run --rm \
            -v "${STAGING_ROOT}/extensions-lts:/work" \
            alpine/git:2.45.2 \
            clone --depth 1 --branch "${branch}" "${repo_url}" "/work/${target_name}" >/dev/null
        return
    fi

    docker run --rm \
        -v "${STAGING_ROOT}/extensions-lts:/work" \
        --entrypoint sh \
        alpine/git:2.45.2 \
        -lc "cd '/work/${target_name}' && git fetch --depth 1 origin '${branch}' && git checkout -f '${branch}' && git reset --hard FETCH_HEAD" >/dev/null
}

current_user=$(id -un)
if [ "${current_user}" != "${STAGING_SERVICE_USER}" ]; then
    echo "Warning: LTS staging runs as ${current_user}; target service user is ${STAGING_SERVICE_USER}." >&2
fi

snapshot_root="${STAGING_ROOT}/backup/snapshots"
if [ ! -d "${snapshot_root}" ] || [ -z "$(find "${snapshot_root}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)" ]; then
    echo "No staging snapshot found in ${snapshot_root}. Run script/snapshot-staging.sh first." >&2
    exit 1
fi

echo "Preparing LTS staging files in ${STAGING_ROOT}"
mkdir -p \
    "${STAGING_ROOT}/backup" \
    "${STAGING_ROOT}/config-lts" \
    "${STAGING_ROOT}/extensions-lts" \
    "${STAGING_ROOT}/images" \
    "${STAGING_ROOT}/Ressourcen"

cp "${REPO_ROOT}/config/mediawiki-lts/LocalSettings.php" "${STAGING_ROOT}/config-lts/LocalSettings.php"
cp "${REPO_ROOT}/config/mediawiki/InfixTitleSearch.php" "${STAGING_ROOT}/config-lts/InfixTitleSearch.php"
cp "${REPO_ROOT}/config/mediawiki-lts/SearchSettings.php" "${STAGING_ROOT}/config-lts/SearchSettings.php"
rsync -a --delete "${REPO_ROOT}/Ressourcen/" "${STAGING_ROOT}/Ressourcen/"
chmod -R a+rX "${STAGING_ROOT}/Ressourcen"
rsync -a --delete "${PROD_ROOT}/images/" "${STAGING_ROOT}/images/"

if [ "${ENABLE_MODERN_SEARCH}" = "1" ]; then
    echo "Preparing CirrusSearch extensions for MediaWiki LTS"
    ensure_lts_extension "https://gerrit.wikimedia.org/r/mediawiki/extensions/Elastica" "${STAGING_ELASTICA_BRANCH}" "${STAGING_ROOT}/extensions-lts/Elastica"
    ensure_lts_extension "https://gerrit.wikimedia.org/r/mediawiki/extensions/CirrusSearch" "${STAGING_CIRRUS_BRANCH}" "${STAGING_ROOT}/extensions-lts/CirrusSearch"
fi

dump_file="${STAGING_ROOT}/backup/wikidb-staging-lts.sql"
if [ "${IMPORT_PRODUCTION_DB}" = "1" ]; then
    echo "Dumping production database to ${dump_file}"
    docker exec mediawiki_mysql sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" wikidb' > "${dump_file}"
fi

echo "Ensuring staging Docker network"
docker network inspect "${STAGING_NETWORK}" >/dev/null 2>&1 || docker network create "${STAGING_NETWORK}" >/dev/null

echo "Replacing old staging containers for in-place LTS test"
docker rm -f "${STAGING_WIKI_CONTAINER}" "${STAGING_DB_CONTAINER}" "${STAGING_ES_CONTAINER}" "${STAGING_SEARCH_CONTAINER}" >/dev/null 2>&1 || true
if [ "${RESET_STAGING_VOLUMES}" = "1" ]; then
    docker volume rm -f mediawiki_mysql_staging esdata_staging "${STAGING_SEARCH_VOLUME}" >/dev/null 2>&1 || true
fi
docker volume create mediawiki_mysql_staging >/dev/null
if [ "${ENABLE_MODERN_SEARCH}" = "1" ]; then
    docker volume create "${STAGING_SEARCH_VOLUME}" >/dev/null
fi

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

if [ "${IMPORT_PRODUCTION_DB}" = "1" ]; then
    echo "Importing production dump into staging database"
    docker exec -i "${STAGING_DB_CONTAINER}" sh -c 'exec mysql -uroot -p"$MYSQL_ROOT_PASSWORD" wikidb' < "${dump_file}"
else
    echo "Keeping existing staging database volume; production import skipped"
fi

if [ "${ENABLE_MODERN_SEARCH}" = "1" ]; then
    echo "Starting Elasticsearch 7.10 for modern CirrusSearch"
    docker run -d \
        --name "${STAGING_SEARCH_CONTAINER}" \
        --network "${STAGING_NETWORK}" \
        -e discovery.type=single-node \
        -e xpack.security.enabled=false \
        -e ES_JAVA_OPTS='-Xms512m -Xmx512m' \
        -v "${STAGING_SEARCH_VOLUME}:/usr/share/elasticsearch/data" \
        "${STAGING_SEARCH_IMAGE}" >/dev/null

    echo "Waiting for Elasticsearch"
    for attempt in $(seq 1 90); do
        if docker logs --tail 200 "${STAGING_SEARCH_CONTAINER}" 2>&1 | grep -q 'started'; then
            break
        fi
        if [ "${attempt}" -eq 90 ]; then
            echo "Elasticsearch did not become ready" >&2
            exit 1
        fi
        sleep 2
    done
fi

echo "Starting MediaWiki LTS on port ${STAGING_HTTP_PORT}"
docker run -d \
    --name "${STAGING_WIKI_CONTAINER}" \
    --network "${STAGING_NETWORK}" \
    --security-opt seccomp=unconfined \
    -p "${STAGING_HTTP_PORT}:${STAGING_CONTAINER_HTTP_PORT}" \
    -e MEDIAWIKI_SERVER="${STAGING_MEDIAWIKI_SERVER}" \
    -e MEDIAWIKI_SITENAME="Trigowiki Staging LTS" \
    -e MEDIAWIKI_LANGUAGE_CODE=de \
    -e MEDIAWIKI_SECRET_KEY="${STAGING_MEDIAWIKI_SECRET_KEY}" \
    -e MEDIAWIKI_DB_TYPE=mysql \
    -e MEDIAWIKI_DB_HOST="${STAGING_DB_CONTAINER}" \
    -e MEDIAWIKI_DB_PORT=3306 \
    -e MEDIAWIKI_DB_NAME=wikidb \
    -e MEDIAWIKI_DB_USER=root \
    -e MEDIAWIKI_DB_TABLE_OPTIONS="ENGINE=InnoDB, DEFAULT CHARSET=binary" \
    -e MEDIAWIKI_DB_PASSWORD="${STAGING_DB_ROOT_PASSWORD}" \
    -e MEDIAWIKI_SEARCH_ENABLED="${ENABLE_MODERN_SEARCH}" \
    -e MEDIAWIKI_SEARCH_HOST="${STAGING_SEARCH_CONTAINER}" \
    -e MEDIAWIKI_ENABLE_UPLOADS=1 \
    -e MEDIAWIKI_DEFAULT_SKIN=vector \
    -v "${STAGING_ROOT}/config-lts/LocalSettings.php:${STAGING_MEDIAWIKI_PATH}/LocalSettings.php:ro" \
    -v "${STAGING_ROOT}/config-lts/InfixTitleSearch.php:${STAGING_MEDIAWIKI_PATH}/InfixTitleSearch.php:ro" \
    -v "${STAGING_ROOT}/config-lts/SearchSettings.php:${STAGING_MEDIAWIKI_PATH}/SearchSettings.php:ro" \
    -v "${STAGING_ROOT}/extensions-lts/Elastica:${STAGING_MEDIAWIKI_PATH}/extensions/Elastica:ro" \
    -v "${STAGING_ROOT}/extensions-lts/CirrusSearch:${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch:ro" \
    -v "${STAGING_ROOT}/images:/images" \
    -v "${STAGING_ROOT}/Ressourcen:${STAGING_MEDIAWIKI_PATH}/resources/trigowiki:ro" \
    "${STAGING_WIKI_IMAGE}" >/dev/null

sleep 15

if [ "${RUN_STAGING_UPDATE}" = "1" ]; then
    echo "Running MediaWiki LTS database update"
    if docker exec "${STAGING_WIKI_CONTAINER}" test -f "${STAGING_MEDIAWIKI_PATH}/maintenance/run.php"; then
        docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/maintenance/run.php" update --quick
    else
        docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/maintenance/update.php" --quick --skip-config-validation
    fi
fi

if [ "${ENABLE_MODERN_SEARCH}" = "1" ] && [ "${RUN_STAGING_REINDEX}" = "1" ]; then
    echo "Rebuilding CirrusSearch index on LTS staging"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/UpdateSearchIndexConfig.php" --reindexAndRemoveOk --indexIdentifier now
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/UpdateSearchIndexConfig.php"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/UpdateSuggesterIndex.php"
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/ForceSearchIndex.php" --skipLinks --indexOnSkip
    docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/extensions/CirrusSearch/maintenance/ForceSearchIndex.php" --skipParse
fi

echo "LTS in-place staging started: ${STAGING_MEDIAWIKI_SERVER}"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' | awk 'NR == 1 || /_staging/'
