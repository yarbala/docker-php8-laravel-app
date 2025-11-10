#!/usr/bin/env bash
# Quick local build-and-smoke-test for php84/testing.Dockerfile
# - Builds the image (single-arch)
# - Runs a container and verifies key tools and PHP extensions

set -euo pipefail

IMAGE_TAG="local/php8-laravel-testing:8.4"
CONTEXT_DIR="$(cd "$(dirname "$0")" && pwd)"
DOCKERFILE_PATH="${CONTEXT_DIR}/testing.Dockerfile"

echo "[1/3] Building image ${IMAGE_TAG} from ${DOCKERFILE_PATH}..."
docker build -t "${IMAGE_TAG}" -f "${DOCKERFILE_PATH}" "${CONTEXT_DIR}"

echo "[2/3] Running smoke tests inside the container..."
# Using default USER from Dockerfile (pwuser). No mounts to keep it hermetic.
docker run --rm "${IMAGE_TAG}" bash -lc '
  set -e
  echo "Node version:" && node -v
  echo "npm version:" && npm -v
  echo "SVGO version:" && svgo --version || echo "SVGO missing"
  echo "Playwright version:" && (playwright --version || echo "Playwright CLI not found")
  echo "PHP version:" && php -v
  echo "Composer version:" && composer --version
  echo "Enabled PHP extensions (subset):" && php -m | egrep -i "^(exif|pcntl|imagick|redis)$" || true
  # Permissions checks
  echo "Testing write permissions in /var/www/html..."
  mkdir -p /var/www/html && echo ok > /var/www/html/_writable_test && ls -l /var/www/html/_writable_test
  echo "Testing composer cache directory writability..."
  mkdir -p /home/pwuser/.cache/composer/files && test -w /home/pwuser/.cache/composer/files && echo "Composer cache is writable"
'

echo "[3/3] All smoke tests executed. If you saw expected versions and no errors, the image is good."
