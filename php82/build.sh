#!/bin/bash

# Exit on any error
set -e

docker build -t yarbala/php8-fpm-laravel-nginx:8.2 -f nginx.Dockerfile .
docker build -t yarbala/php8-laravel-cli:8.2 -f cli.Dockerfile .
