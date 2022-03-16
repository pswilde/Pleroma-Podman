# Pleroma

[Pleroma](https://pleroma.social/) is a federated social networking platform, compatible with GNU social and other OStatus implementations. It is free software licensed under the AGPLv3.

It actually consists of two components: a backend, named simply Pleroma, and a user-facing frontend, named Pleroma-FE.

Its main advantages are its lightness and speed.

![Pleroma](https://i.imgur.com/VftiTlR.png)

_Pleromians trying to understand the memes_

## Features

This Podman set up is adapted from [angristan's docker-pleroma](https://github.com/angristan/docker-pleroma). I muddled my way through the set up to get a final working set up. There may be some missed steps in the below, but ultimately this is what lead me to getting things running nicely.

A quick further note. I have included the `config :pleroma, configurable_from_database: true` configuration and the `pleroma_ctl config migrate_to_db` procedure. This means a lot of the actual config.exs parts can be eliminated completely, but I've left them in for clarity.

- adapted from [angristan/docker-pleroma](https://github.com/angristan/docker-pleroma)
- Based on the elixir:alpine image
- Ran as an unprivileged user
- It works great

As with Angristan's Docker-Pleroma: this is not a reusable (e.g. It can't be uploaded to the Docker Hub), because for now Pleroma needs to compile the configuration. 😢
Thus you will need to build the image yourself, but I explain how to do it below.

## Build-time variables

- **`PLEROMA_VER`** : Pleroma version (latest commit of the [`develop` branch](https://git.pleroma.social/pleroma/pleroma) by default)
- **`GID`**: group id (default: `911`)
- **`UID`**: user id (default: `911`)

## Usage

### Installation

Create a folder for your Pleroma instance. Inside, you should have `Dockerfile` and `podman-run.sh` from this repo.

You should change the `POSTGRES_PASSWORD` variable in the `podman-run.sh` file.

Create the upload and config folder and give write permissions for the uploads:  
The `podman-run.sh` script does this automatically.
```sh
mkdir uploads config
chown -R 911:911 uploads
```

Pleroma needs the `citext` PostgreSQL extension, here is how to add it:

The `podman-run.sh` script does this automatically when run with the `db-setup` argument.
```sh
./podman-run.sh db-setup
```
This creates a pod and the postgresql container then runs the below
```sh 
>You don't need to do this bit<
podman exec -i pleroma-db psql -U pleroma -c "CREATE EXTENSION IF NOT EXISTS citext;"
>You don't need to do that bit<
```

Configure Pleroma. Copy the following to `config/secret.exs`:

```exs
use Mix.Config

config :pleroma, Pleroma.Web.Endpoint,
   http: [ ip: {0, 0, 0, 0}, ],
   url: [host: "pleroma.domain.tld", scheme: "https", port: 443],
   secret_key_base: "<use 'openssl rand -base64 48' to generate a key>"

config :pleroma, :instance,
  name: "Pleroma",
  email: "admin@email.tld",
  limit: 5000,
  registrations_open: true

config :pleroma, :media_proxy,
  enabled: false,
  redirect_on_failure: true,
  base_url: "https://cache.domain.tld"

# Configure your database
config :pleroma, Pleroma.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "pleroma",
  password: "pleroma",
  database: "pleroma",
  hostname: "postgres",
  pool_size: 10
```

You need to change at least:

- `host`
- `secret_key_base`
- `email`

Make sure your PostgreSQL parameters are ok.

You can now build the image. 2 way of doing it:
Again, the `podman-run.sh` script has runtime parameters to do this.
```sh
./podman-run.sh build-setup
```
This builds the container image and does the following:
Sets up the database:

```sh
>You don't need to do this<
podman exec pleroma-web mix ecto.migrate
```
and also... migrates config to the DB
```sh
podman exec pleroma-web /pleroma/bin/pleroma_ctl config migrate_to_db
>You don't need to do that<
```

Get your web push keys and copy them to `secret.exs`:
Again, the `podman-run.sh` script has runtime parameters to do this.
```sh
./podman-run.sh gen-keypair
```
Which sets up the containers again and runs the following:
```
>You don't need to do this<
podman exec pleroma-web mix web_push.gen.keypair
>You don't need to do that<
```
Put the output in your secret.exs (may not be necessary due to DB migration of config, but I've left it here for clarity again)

You will need to build the image again, to pick up your updated `secret.exs` file:
Once again, `podman-run.sh` has a parameter for it:
```sh
./podman-run.sh final-build
```

You can now launch your instance:

```sh
podman pod start pleroma-pod
```

Check if everything went well with:

```sh
podman logs -f pleroma-web
```

You can now setup a HAProxy or Nginx reverse proxy in a container or on your host by using the [example Nginx config](https://git.pleroma.social/pleroma/pleroma/blob/develop/installation/pleroma.nginx).


## Final Notes

As with anything, I've only tested this on my systems, and the process of going through getting things working may have meant some steps are missing from this guide. At some point I will test this process again to ensure the script works well, but if anyone has any queries about it then let me know.

## Other Container images

Here are other Pleroma Container images that helped me build mine:

- [angristan/docker-pleroma](https://github.com/angristan/docker-pleroma) - which this repo is adapted from
- [potproject/docker-pleroma](https://github.com/potproject/docker-pleroma)
- [rysiek/docker-pleroma](https://git.pleroma.social/rysiek/docker-pleroma)
- [RX14/iscute.moe](https://github.com/RX14/kurisu.rx14.co.uk/blob/master/services/iscute.moe/pleroma/Dockerfile)
