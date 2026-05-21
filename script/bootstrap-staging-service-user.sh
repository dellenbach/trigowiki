#!/bin/bash
set -euo pipefail

STAGING_SERVICE_USER=${STAGING_SERVICE_USER:-trigowikisvc}
STAGING_ROOT=${STAGING_ROOT:-/srv/mediawiki-staging}
SSH_KEY_SOURCE_USER=${SSH_KEY_SOURCE_USER:-del}

if [ "$(id -u)" -ne 0 ]; then
    echo "Dieses Skript muss als root oder via sudo ausgefuehrt werden." >&2
    exit 1
fi

if ! getent group docker >/dev/null; then
    echo "Docker-Gruppe wurde nicht gefunden." >&2
    exit 1
fi

if ! id "${STAGING_SERVICE_USER}" >/dev/null 2>&1; then
    useradd \
        --create-home \
        --home-dir "${STAGING_ROOT}" \
        --shell /bin/bash \
        --groups docker \
        "${STAGING_SERVICE_USER}"
else
    usermod --append --groups docker "${STAGING_SERVICE_USER}"
    mkdir -p "${STAGING_ROOT}"
fi

mkdir -p \
    "${STAGING_ROOT}/.ssh" \
    "${STAGING_ROOT}/backup" \
    "${STAGING_ROOT}/config" \
    "${STAGING_ROOT}/images" \
    "${STAGING_ROOT}/Ressourcen" \
    "${STAGING_ROOT}/extensions" \
    "${STAGING_ROOT}/skins" \
    "${STAGING_ROOT}/includes"

if [ -f "/home/${SSH_KEY_SOURCE_USER}/.ssh/authorized_keys" ] && [ ! -s "${STAGING_ROOT}/.ssh/authorized_keys" ]; then
    cp "/home/${SSH_KEY_SOURCE_USER}/.ssh/authorized_keys" "${STAGING_ROOT}/.ssh/authorized_keys"
fi

chown -R "${STAGING_SERVICE_USER}:${STAGING_SERVICE_USER}" "${STAGING_ROOT}"
chmod 700 "${STAGING_ROOT}/.ssh"
if [ -f "${STAGING_ROOT}/.ssh/authorized_keys" ]; then
    chmod 600 "${STAGING_ROOT}/.ssh/authorized_keys"
fi

cat <<EOF
Service-User ist vorbereitet:
  User: ${STAGING_SERVICE_USER}
  Root: ${STAGING_ROOT}

Naechster Test:
  ssh ${STAGING_SERVICE_USER}@$(hostname) 'id; docker ps --format "{{.Names}}" | head'
EOF
