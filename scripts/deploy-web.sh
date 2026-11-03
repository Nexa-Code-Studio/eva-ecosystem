#!/usr/bin/env bash
set -e

ARCHIVE_PATH="${1:-/opt/eva_ai/apps/web/dist.tar.gz}"
WEB_ROOT="/var/www/eva-web"
DOMAIN="eva.nexacode.dev"

if [ ! -f "$ARCHIVE_PATH" ]; then
    echo "Error: Archive file not found at $ARCHIVE_PATH"
    exit 1
fi

echo "Deploying Eva Web from $ARCHIVE_PATH to $WEB_ROOT..."
mkdir -p "$WEB_ROOT"
rm -rf "${WEB_ROOT:?}"/*

# Check if archive contains a top-level directory (dist/ or web/)
if tar -ztf "$ARCHIVE_PATH" | grep -qE "^(dist|web)/"; then
    tar -zxf "$ARCHIVE_PATH" --strip-components=1 -C "$WEB_ROOT"
else
    tar -zxf "$ARCHIVE_PATH" -C "$WEB_ROOT"
fi

if command -v chown >/dev/null 2>&1 && [ "$(id -u)" -eq 0 ]; then
    chown -R www-data:www-data "$WEB_ROOT"
    chmod -R 755 "$WEB_ROOT"
fi

if command -v systemctl >/dev/null 2>&1; then
    systemctl reload nginx || true
fi

echo "Deployment successful! Check https://$DOMAIN"
