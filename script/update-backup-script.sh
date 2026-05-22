#!/bin/bash
set -euo pipefail

# Move updated backup script into production
echo "Updating backup script..."
sudo cp ~/backup-production-daily.sh /srv/mediawiki-production/script/backup-production-daily.sh
sudo chmod +x /srv/mediawiki-production/script/backup-production-daily.sh
sudo chown trigowikisvc:trigowikisvc /srv/mediawiki-production/script/backup-production-daily.sh

echo "✓ Script updated"
echo "Testing new script..."

# Run test
/srv/mediawiki-production/script/backup-production-daily.sh

echo "✓ Test run completed"
