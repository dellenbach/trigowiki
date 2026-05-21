#!/bin/bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
STAGING_DB_ROOT_PASSWORD=${STAGING_DB_ROOT_PASSWORD:-staging-root-change-me}
STAGING_MEDIAWIKI_SECRET_KEY=${STAGING_MEDIAWIKI_SECRET_KEY:-staging-secret-change-me}
STAGING_MEDIAWIKI_PATH=${STAGING_MEDIAWIKI_PATH:-/var/www/html}
STAGING_WIKI_CONTAINER=${STAGING_WIKI_CONTAINER:-mediawiki_wiki_staging}

export STAGING_DB_ROOT_PASSWORD
export STAGING_MEDIAWIKI_SECRET_KEY
export STAGING_MEDIAWIKI_PATH
export STAGING_WIKI_CONTAINER

echo "Phase 1/2: upgrading imported production dump to MediaWiki 1.35"
STAGING_WIKI_IMAGE=mediawiki:1.35 \
RESET_STAGING_VOLUMES=1 \
IMPORT_PRODUCTION_DB=1 \
"${SCRIPT_DIR}/staging-lts-inplace.sh"

echo "Cleaning legacy anonymous user rows after 1.35 actor migration"
docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/maintenance/cleanupUsersWithNoId.php" --prefix 'Imported>' --assign
docker exec "${STAGING_WIKI_CONTAINER}" php "${STAGING_MEDIAWIKI_PATH}/maintenance/update.php" --quick

echo "Phase 2/2: upgrading existing staging database to MediaWiki 1.43"
STAGING_WIKI_IMAGE=mediawiki:1.43 \
RESET_STAGING_VOLUMES=0 \
IMPORT_PRODUCTION_DB=0 \
"${SCRIPT_DIR}/staging-lts-inplace.sh"
