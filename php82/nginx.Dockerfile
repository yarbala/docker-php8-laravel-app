FROM php:8.2-fpm-alpine

LABEL maintainer="yarbala@yarbala.com"

ENV LD_PRELOAD /usr/lib/preloadable_libiconv.so php

RUN apk -U upgrade && apk add --no-cache \
    curl \
    nginx \
    nginx-mod-http-brotli \
    tzdata \
    && ln -s /usr/sbin/php-fpm81 /usr/sbin/php-fpm \
    && addgroup -S php \
    && adduser -S -G php php \
    && rm -rf /var/cache/apk/* /etc/nginx/http.d/* /etc/php81/conf.d/* /etc/php81/php-fpm.d/*

###########################################################################
# s6-overlay
###########################################################################
COPY s6-overlay/s6-overlay-amd64.tar.gz /tmp/
RUN tar xzf /tmp/s6-overlay-amd64.tar.gz -C /

###########################################################################
# Config nginx, php, s6
###########################################################################

COPY conf/services.d /etc/services.d
COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/memory-limit-php.ini /usr/local/etc/php/conf.d/memory-limit-php.ini
COPY conf/logs-php.ini /usr/local/etc/php/conf.d/logs-php.ini
COPY conf/www.conf /usr/local/etc/php-fpm.d/50-www.conf
COPY conf/opcache.ini /usr/local/etc/php/opcache_disabled.ini
COPY conf/default.conf /etc/nginx/conf.d/default.conf

###########################################################################
# Packages
###########################################################################

RUN apk add --update mysql-client zlib-dev libzip-dev bash build-base automake autoconf npm \
  libtool nasm jpegoptim optipng pngquant gifsicle && \
  docker-php-ext-install zip \
  && docker-php-ext-install bcmath \
  && docker-php-ext-install pdo \
  && docker-php-ext-install pdo_mysql \
  && docker-php-ext-install mysqli \
  && apk add --no-cache --repository http://dl-cdn.alpinelinux.org/alpine/edge/community/ --allow-untrusted gnu-libiconv \
  && apk add --no-cache freetype libpng libjpeg-turbo freetype-dev libpng-dev libwebp-tools libwebp-dev libjpeg-turbo-dev \
  && npm install -g svgo \
  && docker-php-ext-configure gd \
    --with-freetype=/usr/include/ \
    --with-jpeg=/usr/include/ \
    --with-webp=/usr/include/ \
  && NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) \
  && docker-php-ext-install -j${NPROC} gd \
  && docker-php-ext-install exif \
  && pecl install redis && docker-php-ext-enable redis \
  && docker-php-source delete && rm -rf /tmp/* \
  && rm -rf /etc/apk/cache

###########################################################################

EXPOSE 80

ENTRYPOINT ["/init"]
CMD []