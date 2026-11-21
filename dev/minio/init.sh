#!/bin/sh
# One-shot MinIO setup for compose.dev.yml (issue #5), the same as iltiam-backend's deploy/minio/init.sh: the five
# buckets the backend uses (private, encrypted, versioned) and the backend's own least-privilege user (read and
# write objects, never delete). Idempotent: scripts/dev.sh runs it on every `up`.
set -eu

BUCKETS="wound-images wound-masks reports prescriptions profile-photos"

echo "Waiting for MinIO..."
tries=0
until mc alias set local "http://minio:9000" "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD" >/dev/null 2>&1; do
  tries=$((tries + 1))
  [ "$tries" -lt 60 ] || { echo "MinIO did not answer in 60 s" >&2; exit 1; }
  sleep 1
done

for bucket in $BUCKETS; do
  mc mb --ignore-existing "local/$bucket" >/dev/null
  mc anonymous set none "local/$bucket" >/dev/null
  mc encrypt set sse-s3 "local/$bucket" >/dev/null
  mc version enable "local/$bucket" >/dev/null
done

mc admin policy create local iltiam-backend /dev-minio/backend-policy.json >/dev/null
mc admin user add local "$STORAGE_ACCESS_KEY" "$STORAGE_SECRET_KEY" >/dev/null
mc admin policy attach local iltiam-backend --user "$STORAGE_ACCESS_KEY" >/dev/null 2>&1 || true

echo "MinIO ready: buckets [$BUCKETS] private, SSE-S3 encrypted, versioned."
