#!/usr/bin/env bash
set -euo pipefail

DOMAIN="giants-of-the-sea.madata.ru"
EMAIL="admin@madata.ru"          # <-- CHANGE THIS
STAGING=0                         # 1 = test against Let's Encrypt staging

COMPOSE="docker compose"

echo "### 1. Creating dummy certificate for $DOMAIN ..."
mkdir -p "./certbot/conf/live/$DOMAIN"
$COMPOSE run --rm --entrypoint "\
  openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
    -keyout '/etc/letsencrypt/live/$DOMAIN/privkey.pem' \
    -out '/etc/letsencrypt/live/$DOMAIN/fullchain.pem' \
    -subj '/CN=localhost'" certbot

echo "### 2. Starting nginx ..."
$COMPOSE up -d nginx

echo "### 3. Deleting dummy certificate ..."
$COMPOSE run --rm --entrypoint "\
  rm -Rf /etc/letsencrypt/live/$DOMAIN && \
  rm -Rf /etc/letsencrypt/archive/$DOMAIN && \
  rm -Rf /etc/letsencrypt/renewal/$DOMAIN.conf" certbot

echo "### 4. Requesting real certificate ..."
STAGING_ARG=""
[ "$STAGING" = "1" ] && STAGING_ARG="--staging"

$COMPOSE run --rm --entrypoint "\
  certbot certonly --webroot -w /var/www/certbot \
    $STAGING_ARG \
    --email $EMAIL \
    -d $DOMAIN \
    --rsa-key-size 4096 \
    --agree-tos \
    --force-renewal \
    --non-interactive" certbot

echo "### 5. Reloading nginx ..."
$COMPOSE exec nginx nginx -s reload

echo "✅ Done! SSL should now be active for https://$DOMAIN"