FROM php:8.2-cli-alpine

LABEL maintainer="yarbala@yarbala.com"

ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

###########################################################################
# Packages
###########################################################################

RUN apk add --update --no-cache nodejs npm tzdata mysql-client zlib-dev libzip-dev bash curl build-base \
  automake autoconf libtool nasm libpng-dev jpeg-dev jpegoptim optipng pngquant gifsicle \
  && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
  && docker-php-ext-install zip \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install pdo \
  && docker-php-ext-install pdo_mysql \
  && docker-php-ext-install mysqli \
  && docker-php-ext-install pcntl \
  && docker-php-ext-configure pcntl --enable-pcntl \
  && apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libwebp-tools libwebp-dev libjpeg-turbo-dev \
  && npm install -g svgo \
  && docker-php-ext-configure gd \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/ \
    --with-webp=/usr/include/ \
  && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
  && docker-php-ext-install -j${NPROC} gd \
  && docker-php-ext-install exif \
  && apk add --no-cache graphviz \
  && pecl install redis && docker-php-ext-enable redis \
  && docker-php-source delete && rm -rf /tmp/* \
  && rm -rf /etc/apk/cache

###########################################################################
# composer
###########################################################################
COPY --from=composer/composer:latest-bin /composer /usr/bin/composer

WORKDIR /var/www/html
