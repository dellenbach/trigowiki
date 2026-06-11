#!/bin/bash
# Erstinstallation der Wiki-Datenbank (nur fuer leere Instanz ohne DB-Import).
# Aufruf: docker exec -it mediawiki_wiki_production bash /srv/script/install.sh <admin-user> <admin-password>
set -euo pipefail

MW_PATH=${MW_PATH:-/var/www/html}

cd "$MW_PATH"

# LocalSettings temporaer verschieben, sonst scheitert installer.php
mv ./LocalSettings.php /tmp/LocalSettings.php

# Installer ausfuehren
php maintenance/run.php install \
  --server="${MEDIAWIKI_SERVER:-http://localhost}" \
  --dbport="${MEDIAWIKI_DB_PORT:-3306}" \
  --dbserver="${MEDIAWIKI_DB_HOST:-mediawiki_mysql_production}" \
  --dbtype="${MEDIAWIKI_DB_TYPE:-mysql}" \
  --dbname="${MEDIAWIKI_DB_NAME:-wikidb}" \
  --installdbuser="${MEDIAWIKI_DB_USER:-root}" \
  --installdbpass="${MEDIAWIKI_DB_PASSWORD}" \
  --dbuser="${MEDIAWIKI_DB_USER:-root}" \
  --dbpass="${MEDIAWIKI_DB_PASSWORD}" \
  --scriptpath='' \
  --pass="$2" \
  Trigowiki "$1"

# Vom Installer erzeugtes LocalSettings entfernen
rm -f ./LocalSettings.php

# Eigenes LocalSettings zurueckstellen
mv /tmp/LocalSettings.php ./LocalSettings.php

echo ""
echo "Fertig. DB-Schema angelegt. Naechster Schritt: Suche indizieren:"
echo "  docker exec mediawiki_wiki_production bash /srv/script/reindex-search.sh"
