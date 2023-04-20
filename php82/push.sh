#!/bin/bash

# Exit on any error
set -e

docker push yarbala/php8-fpm-laravel-nginx:8.2
docker push yarbala/php8-laravel-cli:8.2
