#!/bin/bash
# Suchindex und Suggester neu aufbauen (CirrusSearch / OpenSearch).
# Aufruf: docker exec -it mediawiki_wiki_production bash /srv/script/reindex-search.sh
set -euo pipefail

MW_PATH=${MW_PATH:-/var/www/html}
CIRRUS="${MW_PATH}/extensions/CirrusSearch/maintenance"

php -d memory_limit=1024M "${CIRRUS}/UpdateSearchIndexConfig.php" --reindexAndRemoveOk --indexIdentifier now
php -d memory_limit=1024M "${CIRRUS}/UpdateSearchIndexConfig.php"
php -d memory_limit=1024M "${CIRRUS}/UpdateSuggesterIndex.php"
php -d memory_limit=1024M "${CIRRUS}/ForceSearchIndex.php" --skipLinks --indexOnSkip
php -d memory_limit=1024M "${CIRRUS}/ForceSearchIndex.php" --skipParse

echo "Reindex abgeschlossen."
echo "Smoketest: docker exec mediawiki_wiki_production php ${CIRRUS}/CheckIndexes.php"
