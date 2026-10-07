# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Dockerfiles, config and build scripts for Laravel base images published to Docker Hub. There is no application code, linter, CI or test suite — only image definitions and one smoke-test script.

| Image (tags `8.2`, `8.4`) | Dockerfile (in `php82/`, `php84/`) | Role |
|---|---|---|
| `yarbala/php8-fpm-laravel-nginx` | `nginx.Dockerfile` + `conf/` | Web: nginx + PHP-FPM in one container, supervised by s6-overlay |
| `yarbala/php8-laravel-cli` | `cli.Dockerfile` | CLI: artisan, queue workers, scheduler; has Composer and Node |
| `yarbala/php8-laravel-testing` (`8.4` only) | `php84/testing.Dockerfile` | Browser tests: Playwright image + PHP 8.4 |

## Commands

The build/push scripts use relative paths, so run them from inside the version directory:

```shell
cd php84
./build.sh                         # local single-arch build of the web + CLI images
./push.sh                          # push those two local tags
./build_and_push_multiplatform.sh  # buildx linux/amd64+arm64 build of web + CLI, pushed straight to Docker Hub
./build_and_push_testing.sh        # same, for the testing image (php84 only)
bash test_testing_image.sh         # build the testing image as local/php8-laravel-testing:8.4 and smoke-test it
                                   # (never pushes; the file is not executable, hence `bash`; works from any cwd)

docker build -t yarbala/php8-laravel-cli:8.4 -f cli.Dockerfile .   # build just one image
```

- Only `build.sh` and `test_testing_image.sh` are local-only. The other scripts publish to Docker Hub, and the tags are floating (`8.2`, `8.4`), so a push replaces what every downstream project pulls — don't run them unless explicitly asked.
- `php82/build_and_push_multiplatform.sh` has its `docker buildx create` line commented out, so it uses whichever builder is currently selected. The php84 version creates or reuses a builder named `buildx_instance`.
- There are no automated checks for the web/CLI images. Validate a change by building locally (under a `local/...` tag, as `test_testing_image.sh` does, so the published tag names stay untouched) and inspecting a container: `php -m`, `php --ini`, `php-fpm -tt` (prints the *effective* FPM config), `php-fpm -i | grep opcache`, `nginx -t`, and a multi-megabyte `curl --data-binary` POST against a running container.

### Example stack

`examples/dev` shows how a project consumes the images: thin Dockerfiles `FROM` the published tags, plus MySQL, Redis, MailHog and phpMyAdmin.

```shell
docker network create app_default_network   # once — the compose file joins this external network
cd examples/dev                              # its .env sets COMPOSE_FILE=docker-compose.dev.yml
docker compose build && docker compose up -d
```

- Set `PUID` in `examples/dev/.env` to your host UID; the example Dockerfiles remap `www-data` to it so the bind-mounted `src/` stays writable.
- No ports are published. Services are exposed through `VIRTUAL_HOST` variables (nginx-proxy convention): `laravel-app.localhost` and its `assets.`, `mailhog.` and `pma.` subdomains. A reverse proxy on `app_default_network` is assumed and is not part of this repo; the README also has you add the hostname to `/etc/hosts`.
- The example Dockerfiles pin the `:8.2` tags — edit their `FROM` lines to exercise another version.
- `examples/dev/src` contains only a `phpinfo()` page, so the `queue-worker-application` (`artisan horizon`) and `schedule-application` (`artisan schedule:work`) containers restart-loop until a real Laravel app is placed there.

## Architecture

### Version directories are copies

`php82/` and `php84/` are independent build contexts that share nothing: each has its own Dockerfiles, `conf/`, scripts and vendored s6-overlay tarball, so a config change wanted in both versions has to be made twice. They have diverged: 8.4 adds intl, soap and imagick (plus pcntl, sockets and pcov in the web image), pins exact `php:8.4.x-*-alpine3.y` base tags (keep the web and CLI `FROM` lines on the same release), and its web image is tuned through environment variables (below); 8.2 still has the older, partly broken config layout (see gotchas). Adding a PHP version means copying `php84/` and updating the `FROM` lines and the tags hard-coded in every script.

Extension lists are maintained separately in each Dockerfile. The web and CLI images run the same application code (in the example, web, workspace, queue worker and scheduler all mount the same `src/`), so an extension added to one usually belongs in the other. The testing image installs PHP through apt (`php8.4-*` from the ondrej PPA), not `docker-php-ext-install`.

### Downstream contract

Consumers rely on: app code at `/var/www/html` with docroot `public/`, HTTP on port 80, app processes running as `www-data` (whose UID consumers remap with `usermod`, so anything that must stay writable by the workers needs mode bits that survive a UID change, not just ownership), `ENTRYPOINT ["/init"]` on the web image, the `FPM_*`/`OPCACHE_*` variables of the 8.4 web image, and (8.2 only) `APP_ENV` being read at container start. Treat these as a public interface.

### Web image

`php:<ver>-fpm-alpine` + nginx (with brotli) from apk + s6-overlay as PID 1.

- `conf/services.d/{nginx,php-fpm}/run` are the two supervised services. nginx serves `/var/www/html/public` and passes PHP to FPM on `localhost:9000` (`conf/default.conf`); global nginx settings are in `conf/nginx.conf`. The php-fpm `run` must keep its `#!/usr/bin/with-contenv sh` shebang: s6 strips the container environment, and php-fpm needs it for the `${VAR}` expansion below.
- PHP settings are ini files copied into `/usr/local/etc/php/conf.d/` (the only directory PHP scans); the FPM pool file goes to `/usr/local/etc/php-fpm.d/`. Both directories are read in alphabetical order and the last value wins, so the repo's files are installed with a `zz-` prefix to beat the base image's `www.conf` / `docker-php-ext-*.ini`.
- **8.4 only:** `conf/www.conf` and `conf/opcache.ini` contain `${FPM_*}` / `${OPCACHE_*}` references, which PHP's ini scanner expands from the environment at startup; the defaults are the `ENV` block in `nginx.Dockerfile` (FPM defaults equal the stock pool: dynamic/5/2/1/3). An empty variable makes php-fpm fail to start. OPcache is always on; `conf/pcov.ini` keeps pcov loaded but off (`pcov.enabled=0`, enable per run with `php -d pcov.enabled=1`). `nginx.Dockerfile` also chowns `/var/lib/nginx{,/tmp}` to `www-data` and chmods them 755 so large request bodies can be buffered even after a downstream UID remap.
- **8.2:** `conf/www.conf` is installed as `50-www.conf` and `conf/opcache.ini` outside `conf.d/`, with an `APP_ENV` switch in the php-fpm `run` script — none of which takes effect (see gotchas).
- The vendored s6-overlay is a legacy pre-v3 release (`/etc/services.d`, `/etc/fix-attrs.d` layout). Its init chmods `services.d/*/run` to 0755 at start, which is why those scripts work although they are mode 0644 in git — don't assume that survives an s6-overlay upgrade.

### CLI image

`php:<ver>-cli-alpine` with a similar (not identical) extension list plus Node/npm, Composer and graphviz. It copies nothing from `conf/`, so PHP runs with stock settings (128M `memory_limit`), and it defines no entrypoint — consumers supply the command.

### Testing image

Ubuntu-based, not Alpine: `mcr.microsoft.com/playwright:v1.48.0-noble` with browsers preinstalled, plus Node 22, PHP 8.4 and Composer, running as the upstream `pwuser`. It takes its memory limit from `php84/memory-limit-php.ini` (4G) — a different file from `php84/conf/memory-limit-php.ini` (2G), which belongs to the web image.

## Verified gotchas

Found on 2026-10-06 (confirmed on the published 8.4 image and on `php82`'s identical config files); the first four were fixed in `php84/` on 2026-10-07 and now apply to **`php82/` only**. Remove an entry once the underlying issue is fixed there too.

- **php82: FPM pool sizing in `conf/www.conf` is overridden.** `50-www.conf` is loaded before the base image's stock `www.conf`, whose values win: effective `pm.max_children = 5`, `pm.start_servers = 2`, spare servers 1–3. Only `pm.max_requests` and `pm.process_idle_timeout` take effect, because the stock file doesn't set them. Check with `php-fpm -tt`.
- **php82: `conf/opcache.ini` is never loaded.** Both of its locations are directly in `/usr/local/etc/php/`, but PHP only scans `conf.d/`. The base image enables OPcache itself (stock values: 128 MB, 10000 files, `revalidate_freq=2`) in every environment, so the run script's "NOT enabled" log line is wrong too.
- **php82: `conf/services.d/fix-attrs.d` is never applied.** It ends up at `/etc/services.d/fix-attrs.d`, while s6 reads rules from the `/etc/fix-attrs.d/` directory. Don't "fix" it by moving it there: its `/var/www` rule would recursively chmod the app on every start (stripping `+x` from `vendor/bin`, on a bind mount that means host files). 8.2 is saved from the nginx temp-dir failure only by the explicit `chown` in its Dockerfile — which does not survive a downstream `usermod -u` because `/var/lib/nginx/tmp` stays mode 700.
- **php82: `su www-data` in `php-fpm/run` does not switch users.** The account's shell is `nologin`, which prints "This account is not available" and sleeps, delaying FPM by about 5 s (nginx answers 502 meanwhile). The FPM master then runs as root with `www-data` workers — exactly what happens without the line.
- **Both: the arm64 web image contains x86-64 s6 binaries.** `nginx.Dockerfile` always copies `s6-overlay-amd64.tar.gz`, so on arm64 `/init` only works where the host emulates amd64 (it ran under Rosetta on Docker Desktop).
- **Both: leftovers in the first `RUN` of `nginx.Dockerfile`:** the `php-fpm81` symlink, the `/etc/php81/*` cleanup and the `php` user/group do nothing — PHP comes from the official image under `/usr/local`, and nothing references that user.
- **Both: PHP's own upload limits are stock** (`post_max_size=8M`, `upload_max_filesize=2M`); nginx allows 512M. Projects needing bigger uploads must add their own ini in `conf.d/`.
- **pcov's state does not appear as `pcov.enabled => …` in `php -i`;** look at the `PCOV support => Enabled/Disabled` row (or `ini_get('pcov.enabled')` from a script).
