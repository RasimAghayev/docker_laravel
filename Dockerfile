# syntax=docker/dockerfile:1

# Build order: base -> deps -> build -> test -> runtime.
# Every base image is pinned by tag and digest.

FROM composer:2@sha256:ca11f643d7791ebdd90a34fc20caf11380d434007ae539a9ea75cd9212e13dca AS composer

FROM php:8.3-fpm-alpine@sha256:f9804e0c991b5b339d6fa4fab9edf3c9c9ae68048fb1017cb6dea6265ccef054 AS base

COPY --from=composer /usr/bin/composer /usr/bin/composer

RUN set -eux; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS; \
    docker-php-ext-install -j"$(nproc)" pdo_mysql; \
    apk del .build-deps

RUN addgroup -g 1000 -S app \
    && adduser -u 1000 -S app -G app

ENV COMPOSER_HOME=/tmp/composer \
    COMPOSER_CACHE_DIR=/tmp/composer-cache

WORKDIR /var/www/html
RUN mkdir -p /var/www/html /tmp/composer /tmp/composer-cache \
    && chown -R app:app /var/www/html /tmp/composer /tmp/composer-cache
USER app

FROM base AS deps

COPY --chown=app:app src/composer.json src/composer.lock ./
RUN --mount=type=cache,target=/tmp/composer-cache,uid=1000,gid=1000 \
    composer install --no-interaction --no-progress --prefer-dist \
        --no-dev --no-scripts --no-autoloader

FROM base AS deps-dev

COPY --chown=app:app src/composer.json src/composer.lock ./
RUN --mount=type=cache,target=/tmp/composer-cache,uid=1000,gid=1000 \
    composer install --no-interaction --no-progress --prefer-dist \
        --no-scripts --no-autoloader

FROM deps AS build

COPY --chown=app:app src/ ./
RUN composer dump-autoload --optimize --no-dev \
    && php artisan package:discover --ansi \
    && mkdir -p storage/framework/cache/data storage/framework/sessions \
        storage/framework/views storage/logs bootstrap/cache \
    && chmod -R ug+rwX storage bootstrap/cache

FROM deps-dev AS test

USER root
RUN set -eux; \
    apk add --no-cache --virtual .build-deps $PHPIZE_DEPS; \
    pecl install pcov; \
    docker-php-ext-enable pcov; \
    apk del .build-deps
USER app

COPY --chown=app:app src/ ./
RUN composer dump-autoload --optimize \
    && cp .env.example .env

ENV APP_ENV=testing \
    DB_CONNECTION=sqlite \
    DB_DATABASE=:memory: \
    CACHE_DRIVER=array \
    SESSION_DRIVER=array \
    QUEUE_CONNECTION=sync \
    MAIL_MAILER=array

RUN APP_KEY=base64:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA= \
    vendor/bin/phpunit --testdox --coverage-text --coverage-clover=coverage.xml

FROM base AS runtime

COPY --from=build --chown=app:app /var/www/html /var/www/html
COPY --chown=app:app docker/php/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER app
WORKDIR /var/www/html

EXPOSE 9000
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD php -r 'exit(@fsockopen("127.0.0.1", 9000) ? 0 : 1);'

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php-fpm"]

FROM nginx:stable-alpine@sha256:901e593c95dc85f5a729f5765516321366ef4ac401821431d408897e95287d0a AS web

COPY nginx/default.conf /etc/nginx/conf.d/default.conf
COPY --from=build /var/www/html/public /var/www/html/public

EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD nginx -t