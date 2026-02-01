#!/usr/bin/env bash
set -euo pipefail

# Drop + restore the Komodo test database using a baseline backup.
# Configure via environment variables below.

: "${KOMODO_DB_NAME:=komodo_test}"
: "${KOMODO_DB_USER:?Set KOMODO_DB_USER}"
: "${KOMODO_DB_PASSWORD:?Set KOMODO_DB_PASSWORD}"
: "${KOMODO_DB_ADDRESS:=localhost:27017}"
: "${KOMODO_BACKUP_DIR:?Set KOMODO_BACKUP_DIR to the host path mounted at /backups}"
: "${KOMODO_CLI_IMAGE:=ghcr.io/moghtech/komodo-cli}"
: "${KOMODO_MONGOSH_IMAGE:=mongo:7}"

NETWORK_ARGS=()
if [[ -n "${KOMODO_DOCKER_NETWORK:-}" ]]; then
  NETWORK_ARGS+=("--network" "${KOMODO_DOCKER_NETWORK}")
fi

# Drop the target DB so restore is deterministic (use mongosh container for FerretDB).
docker run --rm \
  "${NETWORK_ARGS[@]}" \
  "${KOMODO_MONGOSH_IMAGE}" \
  mongosh \
  --host "${KOMODO_DB_ADDRESS}" \
  --username "${KOMODO_DB_USER}" \
  --password "${KOMODO_DB_PASSWORD}" \
  --authenticationDatabase admin \
  --eval "db.getSiblingDB('${KOMODO_DB_NAME}').dropDatabase()"

# Restore from /backups using the Komodo CLI image.
docker run --rm \
  "${NETWORK_ARGS[@]}" \
  -v "${KOMODO_BACKUP_DIR}:/backups" \
  -e KOMODO_CLI_DATABASE_TARGET_ADDRESS="${KOMODO_DB_ADDRESS}" \
  -e KOMODO_CLI_DATABASE_TARGET_USERNAME="${KOMODO_DB_USER}" \
  -e KOMODO_CLI_DATABASE_TARGET_PASSWORD="${KOMODO_DB_PASSWORD}" \
  -e KOMODO_CLI_DATABASE_TARGET_DB_NAME="${KOMODO_DB_NAME}" \
  "${KOMODO_CLI_IMAGE}" \
  km database restore -y
