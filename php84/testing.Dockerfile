FROM mcr.microsoft.com/playwright:v1.48.0-noble

LABEL maintainer="yarbala@yarbala.com"

ARG PUID=1000
ENV PUID=${PUID} \
    DEBIAN_FRONTEND=noninteractive \
    COMPOSER_ALLOW_SUPERUSER=1

###########################################################################
# Upgrade Node.js to v22
###########################################################################

RUN npm install -g n && n 22 && npm install -g npm@latest \
    && corepack enable || true

###########################################################################
# Enable Ondrej PHP PPA and update
###########################################################################

RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    ca-certificates \
    gnupg \
    && add-apt-repository -y universe \
    && add-apt-repository ppa:ondrej/php -y \
    && apt-get update

###########################################################################
# Runtime packages + PHP 8.4 extensions
###########################################################################

RUN apt-get install -y --no-install-recommends \
    tzdata \
    bash curl git unzip \
    default-mysql-client \
    graphviz \
    imagemagick \
    php8.4-cli php8.4-dev \
    php8.4-zip php8.4-bcmath \
    php8.4-mysql php8.4-gd \
    php8.4-redis php8.4-curl \
    php8.4-mbstring php8.4-intl \
    php8.4-soap php8.4-xml \
    php8.4-exif \
    php-pear \
    fontconfig fonts-liberation fonts-noto-color-emoji \
    && npm install -g svgo \
    && rm -rf /var/lib/apt/lists*

###########################################################################
# Build deps only for imagick (PECL), then purge to slim image
###########################################################################
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
         build-essential automake autoconf libtool pkg-config \
         libmagickwand-dev libicu-dev libxml2-dev \
    && pecl install imagick \
    && echo "extension=imagick.so" > /etc/php/8.4/cli/conf.d/20-imagick.ini \
    && apt-get purge -y --auto-remove \
         build-essential automake autoconf libtool pkg-config \
         libmagickwand-dev libicu-dev libxml2-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create symbolic link for convenience (force overwrite if exists)
RUN ln -sf /usr/bin/php8.4 /usr/bin/php

###########################################################################
# composer
###########################################################################
COPY --from=composer/composer:latest-bin /composer /usr/bin/composer

###########################################################################
# PHP Configuration
###########################################################################

COPY memory-limit-php.ini /etc/php/8.4/cli/conf.d/99-memory-limit.ini

###########################################################################
# User and workdir for Playwright
###########################################################################
# Use default pwuser from upstream playwright image and ensure project dir exists
RUN mkdir -p /var/www/html && chown -R pwuser:pwuser /var/www

USER pwuser
WORKDIR /var/www/html

# Browsers are already pre-installed in the Playwright image!
# Node.js/npm are already installed (upgraded to v22 above)
# All system dependencies for browsers are already present