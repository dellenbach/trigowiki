#!/usr/bin/env bash
set -euo pipefail

OPENRESTY_ROOT=${OPENRESTY_ROOT:-/srv/openresty}
OPENRESTY_IMAGE=${OPENRESTY_IMAGE:-openresty/openresty:alpine}
OPENRESTY_CONTAINER=${OPENRESTY_CONTAINER:-trigowiki_openresty_test}
OPENRESTY_TEST_PORT=${OPENRESTY_TEST_PORT:-8088}
WIKI_BACKEND=${WIKI_BACKEND:-host.docker.internal:80}
APPSMITH_BACKEND=${APPSMITH_BACKEND:-host.docker.internal:8080}
HOST_GATEWAY=${HOST_GATEWAY:-host-gateway}

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
TEMPLATE=${OPENRESTY_TEMPLATE:-$REPO_ROOT/config/openresty/nginx.conf.template}

if [[ ! -f "$TEMPLATE" ]]; then
    echo "Missing OpenResty template: $TEMPLATE" >&2
    exit 1
fi

mkdir -p "$OPENRESTY_ROOT/config" "$OPENRESTY_ROOT/logs" "$OPENRESTY_ROOT/cache"

sed \
    -e "s#__WIKI_BACKEND__#$WIKI_BACKEND#g" \
    -e "s#__APPSMITH_BACKEND__#$APPSMITH_BACKEND#g" \
    "$TEMPLATE" > "$OPENRESTY_ROOT/config/nginx.conf"

docker rm -f "$OPENRESTY_CONTAINER" >/dev/null 2>&1 || true

docker run -d \
    --name "$OPENRESTY_CONTAINER" \
    --restart unless-stopped \
    --add-host="host.docker.internal:$HOST_GATEWAY" \
    -p "$OPENRESTY_TEST_PORT:80" \
    -v "$OPENRESTY_ROOT/config/nginx.conf:/usr/local/openresty/nginx/conf/nginx.conf:ro" \
    -v "$OPENRESTY_ROOT/logs:/usr/local/openresty/nginx/logs" \
    -v "$OPENRESTY_ROOT/cache:/var/cache/nginx" \
    "$OPENRESTY_IMAGE"

docker exec "$OPENRESTY_CONTAINER" openresty -t

echo "OpenResty test proxy is running on http://localhost:$OPENRESTY_TEST_PORT"
echo "Wiki backend: $WIKI_BACKEND"
echo "Appsmith backend: $APPSMITH_BACKEND"
echo "Host gateway: $HOST_GATEWAY"