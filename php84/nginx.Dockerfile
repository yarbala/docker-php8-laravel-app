# Pinned to the same PHP + Alpine release as cli.Dockerfile; bump both together.
FROM php:8.4.26-fpm-alpine3.24

LABEL maintainer="yarbala@yarbala.com"

ENV LD_PRELOAD="/usr/lib/preloadable_libiconv.so php"

RUN apk -U upgrade && apk add --no-cache \
    curl \
    nginx \
    nginx-mod-http-brotli \
    tzdata \
    && ln -s /usr/sbin/php-fpm81 /usr/sbin/php-fpm \
    && addgroup -S php \
    && adduser -S -G php php \
    && rm -rf /var/cache/apk/* /etc/nginx/http.d/* /etc/php81/conf.d/* /etc/php81/php-fpm.d/*

# nginx buffers large request bodies and upstream responses in /var/lib/nginx/tmp, which the
# Alpine package creates as nginx:nginx 0700 while the workers run as www-data (conf/nginx.conf).
# Hand the tree to www-data and make it traversable, so it keeps working when a downstream
# image remaps www-data's UID (examples/dev does `usermod -u ${PUID} www-data`).
RUN chown www-data:www-data /var/lib/nginx /var/lib/nginx/tmp \
    && chmod 755 /var/lib/nginx /var/lib/nginx/tmp

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
# "zz-" so these are read after the base image's www.conf / docker-php-ext-*.ini (last value wins).
COPY conf/www.conf /usr/local/etc/php-fpm.d/zz-www.conf
COPY conf/opcache.ini /usr/local/etc/php/conf.d/zz-opcache.ini
COPY conf/pcov.ini /usr/local/etc/php/conf.d/zz-pcov.ini
COPY conf/default.conf /etc/nginx/conf.d/default.conf

# Defaults for the ${VAR} references in conf/www.conf and conf/opcache.ini. Override per container
# (-e / compose `environment:`). Never set one to an empty string: PHP-FPM then fails to start.
# The FPM defaults equal what the stock www.conf gave before, so unconfigured containers are unchanged.
ENV FPM_PM=dynamic \
    FPM_MAX_CHILDREN=5 \
    FPM_START_SERVERS=2 \
    FPM_MIN_SPARE_SERVERS=1 \
    FPM_MAX_SPARE_SERVERS=3 \
    OPCACHE_MEMORY_CONSUMPTION=256 \
    OPCACHE_MAX_ACCELERATED_FILES=30000 \
    OPCACHE_VALIDATE_TIMESTAMPS=1 \
    OPCACHE_REVALIDATE_FREQ=2

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
  && rm -rf /etc/apk/cache \
  && apk add --no-cache \
    imagemagick \
    imagemagick-dev \
    && pecl install imagick \
    && docker-php-ext-enable imagick \
  && apk add icu-dev libxml2-dev ghostscript \
  && docker-php-ext-configure intl && docker-php-ext-install intl \
  && docker-php-ext-configure intl && docker-php-ext-install soap \
  && docker-php-ext-install pcntl \
  && apk add --no-cache linux-headers \
  && docker-php-ext-install sockets \
  && pecl install pcov && docker-php-ext-enable pcov

###########################################################################

EXPOSE 80

ENTRYPOINT ["/init"]
CMD []