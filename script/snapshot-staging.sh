#!/bin/bash
set -euo pipefail

STAGING_ROOT=${STAGING_ROOT:-/srv/mediawiki-staging}
STAGING_SNAPSHOT_ROOT=${STAGING_SNAPSHOT_ROOT:-${STAGING_ROOT}/backup/snapshots}
STAGING_DB_CONTAINER=${STAGING_DB_CONTAINER:-mediawiki_mysql_staging}
STAGING_WIKI_CONTAINER=${STAGING_WIKI_CONTAINER:-mediawiki_wiki_staging}
STAGING_ES_CONTAINER=${STAGING_ES_CONTAINER:-elasticsearch_staging}
STAGING_SNAPSHOT_ARCHIVE_FILES=${STAGING_SNAPSHOT_ARCHIVE_FILES:-1}

snapshot_id=${SNAPSHOT_ID:-$(date -u +%Y%m%dT%H%M%SZ)}
snapshot_dir="${STAGING_SNAPSHOT_ROOT}/${snapshot_id}"

if [ ! -d "${STAGING_ROOT}" ]; then
    echo "Staging root not found: ${STAGING_ROOT}" >&2
    exit 1
fi

mkdir -p "${snapshot_dir}"

echo "Creating staging snapshot ${snapshot_dir}"

echo "Writing metadata"
{
    echo "snapshot_id=${snapshot_id}"
    echo "created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "staging_root=${STAGING_ROOT}"
    echo "staging_db_container=${STAGING_DB_CONTAINER}"
    echo "staging_wiki_container=${STAGING_WIKI_CONTAINER}"
    echo "staging_es_container=${STAGING_ES_CONTAINER}"
    echo "git_commit=${GIT_COMMIT:-unknown}"
} > "${snapshot_dir}/metadata.env"

echo "Saving container inventory"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' > "${snapshot_dir}/docker-ps.txt"
docker inspect "${STAGING_WIKI_CONTAINER}" "${STAGING_DB_CONTAINER}" "${STAGING_ES_CONTAINER}" > "${snapshot_dir}/docker-inspect.json"
docker volume inspect mediawiki_mysql_staging esdata_staging > "${snapshot_dir}/docker-volumes.json"

echo "Dumping staging database"
docker exec "${STAGING_DB_CONTAINER}" sh -c 'exec mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" wikidb' > "${snapshot_dir}/wikidb-staging.sql"

if [ "${STAGING_SNAPSHOT_ARCHIVE_FILES}" = "1" ]; then
    echo "Archiving staging files"
    staging_parent=$(dirname "${STAGING_ROOT}")
    staging_name=$(basename "${STAGING_ROOT}")
    tar \
        --exclude="${staging_name}/backup/snapshots" \
        -C "${staging_parent}" \
        -czf "${snapshot_dir}/staging-files.tgz" \
        "${staging_name}"
else
    echo "Skipping staging file archive because STAGING_SNAPSHOT_ARCHIVE_FILES=0"
fi

echo "Writing restore notes"
cat > "${snapshot_dir}/RESTORE.md" <<EOF
# Staging Snapshot ${snapshot_id}

This snapshot captures the staging files and staging database before an in-place upgrade.

Contents:

- metadata.env: snapshot metadata
- docker-ps.txt: container status at snapshot time
- docker-inspect.json: container configuration
- docker-volumes.json: Docker volume metadata
- wikidb-staging.sql: staging database dump
- staging-files.tgz: archive of ${STAGING_ROOT}, when STAGING_SNAPSHOT_ARCHIVE_FILES=1

Restore outline:

1. Stop staging containers with suffix _staging.
2. Restore ${STAGING_ROOT} from staging-files.tgz.
3. Recreate staging DB volume/container.
4. Import wikidb-staging.sql.
5. Recreate search index from MediaWiki maintenance scripts.
EOF

find "${snapshot_dir}" -maxdepth 1 -type f -printf '%f %s bytes\n' | sort

echo "Snapshot completed: ${snapshot_dir}"
