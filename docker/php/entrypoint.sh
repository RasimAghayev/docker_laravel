#!/bin/sh
set -e

if [ -z "${APP_KEY:-}" ]; then
    APP_KEY="$(php artisan key:generate --show)"
    export APP_KEY
fi

if [ -n "${DB_HOST:-}" ] && [ -n "${DB_PORT:-}" ]; then
    until php -r 'exit(@fsockopen(getenv("DB_HOST"), (int) getenv("DB_PORT"), $errno, $errstr, 1) ? 0 : 1);' 2>/dev/null; do
        echo "waiting for ${DB_HOST}:${DB_PORT}..."
        sleep 1
    done
fi

exec "$@"