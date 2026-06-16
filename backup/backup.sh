#!/usr/bin/env bash
# saasERP — Datenbank-Backup (pg_dump + gzip).
#
# Wird entweder manuell oder über den Docker-Compose-Profile "backup" per
# Cron aufgerufen. Backups landen in BACKUP_DIR (Default: /backups), werden
# nach BACKUP_RETENTION_DAYS (Default: 30) automatisch bereinigt.
#
# Umgebungsvariablen werden aus dem aufrufenden Container/Shell geerbt:
#   POSTGRES_HOST, POSTGRES_PORT, POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD
#   BACKUP_DIR, BACKUP_RETENTION_DAYS

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date -u +"%Y%m%dT%H%M%SZ")
FILENAME="${POSTGRES_DB:-saaserp}_${TIMESTAMP}.sql.gz"
TARGET="${BACKUP_DIR}/${FILENAME}"

mkdir -p "${BACKUP_DIR}"

export PGPASSWORD="${POSTGRES_PASSWORD:-}"

echo "[backup] Starte Backup: ${POSTGRES_DB:-saaserp} → ${TARGET}"
pg_dump \
  --host="${POSTGRES_HOST:-localhost}" \
  --port="${POSTGRES_PORT:-5432}" \
  --username="${POSTGRES_USER:-saaserp}" \
  --dbname="${POSTGRES_DB:-saaserp}" \
  --no-password \
  --format=plain \
  | gzip > "${TARGET}"

SIZE=$(du -sh "${TARGET}" | cut -f1)
echo "[backup] Backup abgeschlossen: ${FILENAME} (${SIZE})"

# Alte Backups bereinigen
echo "[backup] Bereinige Backups älter als ${RETENTION_DAYS} Tage..."
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime "+${RETENTION_DAYS}" -delete
REMAINING=$(find "${BACKUP_DIR}" -name "*.sql.gz" | wc -l)
echo "[backup] Verbleibende Backups: ${REMAINING}"
