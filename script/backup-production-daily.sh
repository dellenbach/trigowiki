#!/bin/bash
set -euo pipefail

PROD_ROOT=${PROD_ROOT:-/srv/mediawiki-production}
BACKUP_ROOT=${BACKUP_ROOT:-${PROD_ROOT}/backup}
BACKUP_SUBDIR=${BACKUP_SUBDIR:-daily}
DB_CONTAINER=${DB_CONTAINER:-mediawiki_mysql_production}
DB_NAME=${DB_NAME:-wikidb}
DB_USER=${DB_USER:-root}
HELPER_IMAGE=${HELPER_IMAGE:-mediawiki:1.45.3}
FILE_UID=${FILE_UID:-1004}
FILE_GID=${FILE_GID:-1006}
RETENTION_COUNT=${RETENTION_COUNT:-3}
MIN_FREE_MB=${MIN_FREE_MB:-4096}

snapshot_id=${SNAPSHOT_ID:-$(date -u +%Y%m%dT%H%M%SZ)}

if [ ! -d "${PROD_ROOT}" ]; then
    echo "Production root not found: ${PROD_ROOT}" >&2
    exit 1
fi

available_mb=$(df -Pm "${PROD_ROOT}" | awk 'NR == 2 { print $4 }')
if [ "${available_mb}" -lt "${MIN_FREE_MB}" ]; then
    echo "Not enough free space below ${PROD_ROOT}: ${available_mb} MB available, ${MIN_FREE_MB} MB required." >&2
    exit 1
fi

helper() {
    docker run --rm \
        --user "${FILE_UID}:${FILE_GID}" \
        -v "${PROD_ROOT}:/src:ro" \
        -v "${BACKUP_ROOT}:/backup" \
        -e SNAPSHOT_ID="${snapshot_id}" \
        -e BACKUP_SUBDIR="${BACKUP_SUBDIR}" \
        -e RETENTION_MINUTES="${retention_minutes}" \
        "${HELPER_IMAGE}" "$@"
}

echo "Creating daily production backup ${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}"

# Create metadata file directly on host
mkdir -p "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}"
{
    echo "snapshot_id=${snapshot_id}"
    echo "created_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "prod_root=${PROD_ROOT}"
    echo "db_container=${DB_CONTAINER}"
    echo "db_name=${DB_NAME}"
    echo "retention_count=${RETENTION_COUNT}"
    echo "included_paths=images config config-lts Ressourcen"
} > "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}/metadata.env"

# Create docker-ps snapshot
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}' \
    > "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}/docker-ps.txt"

echo "Dumping database ${DB_NAME} from ${DB_CONTAINER}"
docker exec "${DB_CONTAINER}" sh -c "exec mysqldump -u'${DB_USER}' -p\"\$MYSQL_ROOT_PASSWORD\" '${DB_NAME}'" \
    > "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}/wikidb-production.sql"

echo "Archiving uploads and configuration"
docker run --rm \
    --user "${FILE_UID}:${FILE_GID}" \
    -v "${PROD_ROOT}:/src:ro" \
    -v "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}:/output" \
    "${HELPER_IMAGE}" tar -C /src -czf "/output/uploads-config.tgz" \
    images config config-lts Ressourcen

echo "Cleanup old backups (keeping last ${RETENTION_COUNT})"
ls -1 "${BACKUP_ROOT}/${BACKUP_SUBDIR}" | sort -r | tail -n "+$((RETENTION_COUNT + 1))" | while read -r old; do
    echo "Removing: ${BACKUP_ROOT}/${BACKUP_SUBDIR}/${old}"
    rm -rf "${BACKUP_ROOT}/${BACKUP_SUBDIR}/${old}"
done

echo "Listing backup contents"
docker run --rm \
    --user "${FILE_UID}:${FILE_GID}" \
    -v "${BACKUP_ROOT}:/backup" \
    -e "BACKUP_SUBDIR=${BACKUP_SUBDIR}" \
    -e "SNAPSHOT_ID=${snapshot_id}" \
    "${HELPER_IMAGE}" \
    sh -c 'find "/backup/${BACKUP_SUBDIR}/${SNAPSHOT_ID}" -maxdepth 1 -type f -printf "%f %s bytes\n" | sort'

echo "Daily production backup completed: ${BACKUP_ROOT}/${BACKUP_SUBDIR}/${snapshot_id}"