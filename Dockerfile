# syntax=docker/dockerfile:1.7

FROM composer:2.8 AS vendor
WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --prefer-dist \
    --optimize-autoloader \
    --classmap-authoritative \
    --no-scripts

FROM node:22-alpine AS frontend
WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . ./
RUN npm run build

FROM php:8.3-fpm-alpine AS runtime
WORKDIR /var/www/html

RUN set -eux; \
    apk add --no-cache \
    fcgi \
    icu-libs \
    libzip \
    postgresql-libs \
    tzdata; \
    apk add --no-cache --virtual .build-deps \
    $PHPIZE_DEPS \
    icu-dev \
    libzip-dev \
    postgresql-dev; \
    docker-php-ext-configure intl; \
    docker-php-ext-install -j"$(nproc)" \
    bcmath \
    intl \
    opcache \
    pcntl \
    pdo_pgsql \
    zip; \
    pecl install redis; \
    docker-php-ext-enable redis; \
    apk del .build-deps; \
    rm -rf /tmp/pear

COPY . ./
COPY --from=vendor /app/vendor ./vendor
COPY --from=frontend /app/public/build ./public/build

RUN set -eux; \
    mkdir -p storage/framework/{cache,sessions,views} storage/logs bootstrap/cache; \
    chown -R www-data:www-data storage bootstrap/cache; \
    chmod -R ug+rwx storage bootstrap/cache

ENV APP_ENV=production \
    APP_DEBUG=false \
    PHP_FPM_PM_MAX_CHILDREN=80

USER www-data

EXPOSE 9000

CMD ["php-fpm", "-F"]
