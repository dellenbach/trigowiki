#!/bin/bash
# setup-cron-trigowikisvc.sh
#
# Richtet den taeglichen Backup-Cron-Job fuer trigowikisvc ein.
# Aufruf: sudo bash /srv/mediawiki-production/script/setup-cron-trigowikisvc.sh
#
# Das Backup-Script liegt bereits unter PROD_ROOT/script/ (wird via setup-new-server.sh oder
# deploy-trigowiki.ps1 dorthin kopiert). Kein separates Kopieren notwendig.
set -euo pipefail

PROD_ROOT=${PROD_ROOT:-/srv/mediawiki-production}
SERVICE_USER=${SERVICE_USER:-trigowikisvc}
SCRIPT_DST="${PROD_ROOT}/script/backup-production-daily.sh"
LOG_PATH="${PROD_ROOT}/backup-production.log"

if [ "$(id -u)" -ne 0 ]; then
    echo "Dieses Script muss als root oder via sudo ausgefuehrt werden." >&2
    exit 1
fi

if [ ! -f "$SCRIPT_DST" ]; then
    echo "FEHLER: $SCRIPT_DST nicht gefunden." >&2
    echo "Bitte erst setup-new-server.sh ausfuehren oder deploy-trigowiki.ps1 nutzen." >&2
    exit 1
fi

echo "Setze Rechte fuer $SCRIPT_DST..."
chmod +x "$SCRIPT_DST"
chown "${SERVICE_USER}:${SERVICE_USER}" "$SCRIPT_DST"

echo "Richte Cron-Job fuer $SERVICE_USER ein..."
CRON_JOB="0 2 * * * $SCRIPT_DST >> $LOG_PATH 2>&1"
# Bestehende Crontab lesen, Backup-Zeile entfernen, neue eintragen
(crontab -u "$SERVICE_USER" -l 2>/dev/null | grep -v "$SCRIPT_DST"; echo "$CRON_JOB") \
    | crontab -u "$SERVICE_USER" -

echo "Verifikation:"
crontab -u "$SERVICE_USER" -l
echo "Cron-Job erfolgreich eingerichtet."
