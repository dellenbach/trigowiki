#!/bin/bash
set -euo pipefail

# Dieses Script richtet den Cron-Job für trigowikisvc ein
# Anleitung: Auf brisen als del ausführen, dann sudo-Passwort eingeben

SCRIPT_SRC="/home/del/backup-production-daily.sh"
SCRIPT_DST="/srv/mediawiki-production/script/backup-production-daily.sh"
LOG_PATH="/srv/mediawiki-production/backup-production.log"

echo "Setup Cron-Job für trigowikisvc..."

# 1. Script kopieren und Rechte setzen
echo "Kopiere Script zu $SCRIPT_DST"
sudo cp "$SCRIPT_SRC" "$SCRIPT_DST"
sudo chmod +x "$SCRIPT_DST"
sudo chown trigowikisvc:trigowikisvc "$SCRIPT_DST"

# 2. Cron-Job einrichten
echo "Richte Cron-Job ein..."
CRON_JOB="0 2 * * * $SCRIPT_DST >> $LOG_PATH 2>&1"
sudo crontab -u trigowikisvc -r 2>/dev/null || true
echo "$CRON_JOB" | sudo crontab -u trigowikisvc -

# 3. Verifizieren
echo "Verifikation:"
sudo crontab -u trigowikisvc -l
echo "✓ Cron-Job erfolgreich eingerichtet!"
