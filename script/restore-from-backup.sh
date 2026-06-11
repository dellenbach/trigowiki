#!/usr/bin/env bash
# restore-from-backup.sh
#
# Importiert einen MySQL-Dump in den laufenden mediawiki_mysql_production-Container.
#
# Aufruf:
#   bash /srv/mediawiki-production/script/restore-from-backup.sh /pfad/zum/wikidb.sql
#
# Der Wiki-Container wird danach neu gestartet, damit die DB-Verbindung frisch initialisiert wird.
# Anschliessend Suchindex aufbauen: bash /srv/mediawiki-production/script/reindex-search.sh

set -euo pipefail

DUMP_FILE=${1:?"Aufruf: $0 /pfad/zum/wikidb.sql"}
DB_CONTAINER=${DB_CONTAINER:-mediawiki_mysql_production}
DB_NAME=${DB_NAME:-wikidb}
DB_USER=${DB_USER:-root}
WIKI_CONTAINER=${WIKI_CONTAINER:-mediawiki_wiki_production}

if [ ! -f "$DUMP_FILE" ]; then
    echo "Dump-Datei nicht gefunden: $DUMP_FILE" >&2
    exit 1
fi

echo "Importiere $DUMP_FILE in $DB_CONTAINER / $DB_NAME ..."
docker exec -i "$DB_CONTAINER" \
    sh -c "exec mysql -u\"${DB_USER}\" -p\"\$MYSQL_ROOT_PASSWORD\" \"${DB_NAME}\"" \
    < "$DUMP_FILE"

echo "DB-Import abgeschlossen."

echo "Fuehre MediaWiki-Schema-Update aus (falls noetig)..."
docker exec "$WIKI_CONTAINER" php /var/www/html/maintenance/run.php update --quick || true

echo "Fertig."
echo "Naechster Schritt: Suchindex aufbauen:"
echo "  docker exec $WIKI_CONTAINER bash /srv/mediawiki-production/script/reindex-search.sh"
