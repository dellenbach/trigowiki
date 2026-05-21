FROM kristophjunge/mediawiki AS trigowiki
LABEL maintainer="Marco Dellenbach <marco.dellenbach@trigonet.ch>" \
	version="0.9"


#RUN apt-get install apt-transport-https && apt-get update && apt-get install elasticsearch

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 
RUN if [ -d /var/www/mediawiki/extensions/Elastica ]; then cd /var/www/mediawiki/extensions/Elastica && composer install --no-dev; fi

RUN if [ -f /var/www/mediawiki/extensions/SyntaxHighlight_GeSHi/pygments/pygmentize ]; then chmod a+x /var/www/mediawiki/extensions/SyntaxHighlight_GeSHi/pygments/pygmentize; fi

COPY docker-entrypoint.sh /docker-entrypoint.sh
COPY config/php-fpm/php-fpm.conf /usr/local/etc/php-fpm.conf
COPY config/parsoid/config.yaml /usr/lib/parsoid/src/config.yaml
COPY config/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf
COPY config/supervisor/kill_supervisor.py /usr/bin/kill_supervisor.py

RUN chmod 755 /docker-entrypoint.sh /usr/bin/kill_supervisor.py

