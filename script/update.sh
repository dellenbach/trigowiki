#!/bin/bash
# MediaWiki-Datenbank-Update nach Konfigurations- oder Schema-Aenderungen.
# Aufruf: docker exec -it mediawiki_wiki_production bash /srv/script/update.sh
set -euo pipefail

MW_PATH=${MW_PATH:-/var/www/html}

cd "$MW_PATH"
php maintenance/run.php update --quick
