#!/bin/bash

# Exit on any error
set -e

docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v8 -t yarbala/php8-fpm-laravel-nginx:8.2 --push -f nginx.Dockerfile .
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/v7,linux/arm/v8 -t yarbala/php8-laravel-cli:8.2 --push -f cli.Dockerfile .
