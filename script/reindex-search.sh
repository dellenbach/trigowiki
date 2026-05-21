#!/bin/bash
set -e

php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php --reindexAndRemoveOk --indexIdentifier now
php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSearchIndexConfig.php
php /var/www/mediawiki/extensions/CirrusSearch/maintenance/updateSuggesterIndex.php
php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipLinks --indexOnSkip
php /var/www/mediawiki/extensions/CirrusSearch/maintenance/forceSearchIndex.php --skipParse
