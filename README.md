

Add to ``/etc/hosts``

```
laravel-app.localhost
```

Add docker network, if not exists

```shell
$ docker network create app_default_network
```

in .env change PUID to your UID,

build images and run

```shell
$ cd /path/to/examples/dev
$ docker-compose build
$ docker-compose up -d
```

## Web image 8.4: runtime settings

`yarbala/php8-fpm-laravel-nginx:8.4` reads its PHP-FPM pool and OPcache settings from
environment variables. Without any variables the container behaves exactly like before.

| Variable | Default | Directive |
|---|---|---|
| `FPM_PM` | `dynamic` | `pm` |
| `FPM_MAX_CHILDREN` | `5` | `pm.max_children` |
| `FPM_START_SERVERS` | `2` | `pm.start_servers` |
| `FPM_MIN_SPARE_SERVERS` | `1` | `pm.min_spare_servers` |
| `FPM_MAX_SPARE_SERVERS` | `3` | `pm.max_spare_servers` |
| `OPCACHE_MEMORY_CONSUMPTION` | `256` | `opcache.memory_consumption` (MB) |
| `OPCACHE_MAX_ACCELERATED_FILES` | `30000` | `opcache.max_accelerated_files` |
| `OPCACHE_VALIDATE_TIMESTAMPS` | `1` | `opcache.validate_timestamps` |
| `OPCACHE_REVALIDATE_FREQ` | `2` | `opcache.revalidate_freq` (seconds) |

OPcache is always on. Never set a variable to an empty string — PHP-FPM will refuse to start.
Check the effective values inside the container with `php-fpm -tt` and `php-fpm -i | grep opcache`.

`pcov` is installed but disabled (`pcov.enabled=0`). Enable it for a coverage run only:

```shell
$ php -d pcov.enabled=1 vendor/bin/pest --coverage
```

The 8.2 images have none of this.

