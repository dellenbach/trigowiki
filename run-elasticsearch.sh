#!/bin/bash
set -e

mkdir -p ${ES_VOLUME}/data
mkdir -p ${ES_VOLUME}/logs

OPTS="${OPTS} \
-Des.default.network.host=0.0.0.0 \
-Des.default.path.data=${ES_VOLUME}/data \
-Des.default.path.logs=${ES_VOLUME}/logs \
-Des.default.rootLogger=${ES_LOGGER_LEVEL},\ console \
-Des.default.logger.deprecation=INFO,\ console \
-Des.default.logger.index.search.slowlog=TRACE,\ console \
-Des.default.logger.index.indexing.slowlog=TRACE,\ console"

echo "Starting Elasticsearch with the options ${OPTS}"
CMD="${ES_HOME}/bin/elasticsearch ${OPTS}"
if [ `id -u` = 0 ]; then
  echo "Running as non-root..."
  chown -R ${ES_USER}:${ES_USER} ${ES_VOLUME}
  su -c "${CMD}" ${ES_USER}
else
  ${CMD}
fi
