FROM yarbala/php8-fpm-laravel-nginx:8.2

ARG PUID=1000
ENV PUID ${PUID}

###########################################################################
# Customize image here
###########################################################################

RUN apk --no-cache add shadow && usermod -u ${PUID} www-data

EXPOSE 80

ENTRYPOINT ["/init"]
CMD []