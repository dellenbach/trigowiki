#!/bin/bash
set -euo pipefail

PROD_ROOT=${PROD_ROOT:-/srv/mediawiki}
PROD_SNAPSHOT_ROOT=${PROD_SNAPSHOT_ROOT:-${PROD_ROOT}/backup/snapshots}
PROD_DB_CONTAINER=${PROD_DB_CONTAINER:-mediawiki_mysql}
PROD_WIKI_CONTAINER=${PROD_WIKI_CONTAINER:-mediawiki_wiki}
PROD_ES_CONTAINER=${PROD_ES_CONTAINER:-11f951d24998_elasticsearch}
PROD_DB_NAME=${PROD_DB_NAME:-wikidb}
PROD_MYSQL_USER=${PROD_MYSQL_USER:-root}
PROD_SNAPSHOT_ARCHIVE_FILES=${PROD_SNAPSHOT_ARCHIVE_FILES:-1}
PROD_SNAPSHOT_MIN_FREE_MB=${PROD_SNAPSHOT_MIN_FREE_MB:-5120}

snapshot_id=${SNAPSHOT_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
snapshot_dir="${PROD_SNAPSHOT_ROOT}/${snapshot_id}"

if [ ! -d "${PROD_ROOT}" ]; then
    echo "Production root not found: ${PROD_ROOT}" >&2
    exit 1
fi

available_mb=$(df -Pm "${PROD_ROOT}" | awk 'NR == 2 { print $4 }')
if [ "${available_mb}" -lt "${PROD_SNAPSHOT_MIN_FREE_MB}" ]; then
    echo "Not enough free space below ${PROD_ROOT}: ${available_mb} MB available, ${PROD_SNAPSHOT_MIN_FREE_MB} MB required." >&2
    echo "Set PROD_SNAPSHOT_MIN_FREE_MB to a lower value only for an intentional emergency snapshot." >&2
    exit 1
fi

mkdir -p "${snapshot_dir}"

echo "Creating production snapshot ${snapshot_dir}"

echo "Writing metadata"
{
    echo "snapshot_id=${snapshot_id}"
    echo "created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "prod_root=${PROD_ROOT}"
    echo "prod_db_container=${PROD_DB_CONTAINER}"
    echo "prod_wiki_container=${PROD_WIKI_CONTAINER}"
    echo "prod_es_container=${PROD_ES_CONTAINER}"
    echo "prod_db_name=${PROD_DB_NAME}"
    echo "git_commit=${GIT_COMMIT:-unknown}"
} > "${snapshot_dir}/metadata.env"

echo "Saving container inventory"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "${snapshot_dir}/docker-ps.txt"
docker inspect "${PROD_WIKI_CONTAINER}" "${PROD_DB_CONTAINER}" "${PROD_ES_CONTAINER}" > "${snapshot_dir}/docker-inspect.json"
docker volume ls > "${snapshot_dir}/docker-volumes.txt"

echo "Dumping production database"
docker exec "${PROD_DB_CONTAINER}" sh -c "exec mysqldump -u'${PROD_MYSQL_USER}' -p\"\$MYSQL_ROOT_PASSWORD\" '${PROD_DB_NAME}'" > "${snapshot_dir}/wikidb-production.sql"

if [ "${PROD_SNAPSHOT_ARCHIVE_FILES}" = "1" ]; then
    echo "Archiving production files"
    prod_parent=$(dirname "${PROD_ROOT}")
    prod_name=$(basename "${PROD_ROOT}")
    tar \
        --exclude="${prod_name}/backup/snapshots" \
        -C "${prod_parent}" \
        -czf "${snapshot_dir}/production-files.tgz" \
        "${prod_name}"
else
    echo "Skipping production file archive because PROD_SNAPSHOT_ARCHIVE_FILES=0"
fi

echo "Writing restore notes"
cat > "${snapshot_dir}/RESTORE.md" <<EOF
# Production Snapshot ${snapshot_id}

This snapshot captures production metadata, database dump, and optionally production files.

Contents:

- metadata.env: snapshot metadata
- docker-ps.txt: container status at snapshot time
- docker-inspect.json: container configuration
- docker-volumes.txt: Docker volume list
- wikidb-production.sql: production database dump
- production-files.tgz: archive of ${PROD_ROOT}, when PROD_SNAPSHOT_ARCHIVE_FILES=1

Restore outline:

1. Stop replacement MediaWiki and database containers.
2. Restore ${PROD_ROOT} from production-files.tgz if needed.
3. Recreate the database volume/container.
4. Import wikidb-production.sql into ${PROD_DB_NAME}.
5. Recreate the search index with the MediaWiki/CirrusSearch maintenance scripts.
6. Validate login, upload rendering, search, and container logs before opening traffic.
EOF

find "${snapshot_dir}" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort

echo "Production snapshot completed: ${snapshot_dir}"
