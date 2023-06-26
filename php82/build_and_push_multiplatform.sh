#!/bin/bash

# Exit on any error
set -e

#docker buildx create --use --name buildx_instance

docker buildx build --platform linux/amd64,linux/arm64 -t yarbala/php8-fpm-laravel-nginx:8.2 --push -f nginx.Dockerfile .
docker buildx build --platform linux/amd64,linux/arm64 -t yarbala/php8-laravel-cli:8.2 --push -f cli.Dockerfile .

#docker buildx stop buildx_instance