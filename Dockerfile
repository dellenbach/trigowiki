FROM kristophjunge/mediawiki AS trigowiki
MAINTAINER Marco Dellenbach <marco.dellenbach@trigonet.ch> version: 0.9


#RUN apt-get install apt-transport-https && apt-get update && apt-get install elasticsearch

RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 
RUN cd /var/www/mediawiki/extensions/Elastica
RUN composer install --no-dev

run chmod a+x /var/www/mediawiki/extensions/SyntaxHighlight_GeSHi/pygments/pygmentize

