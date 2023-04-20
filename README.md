

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

