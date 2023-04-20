FROM yarbala/php8-laravel-cli:8.2

ARG PUID=1000
ENV PUID ${PUID}

###########################################################################
# Customize image here
###########################################################################

RUN apk --no-cache add shadow && usermod -u ${PUID} www-data

EXPOSE 80

WORKDIR /var/www/html