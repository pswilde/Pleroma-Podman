#!/bin/bash

mkdir ./postgres 
mkdir ./uploads
mkdir ./static
touch config.exs
chown -R 911:911 ./uploads

podman pod create \
    --name pleroma-pod \
    -p 4000:4000

podman run -d \
    --name pleroma-db \
    --pod pleroma-pod \
    -e POSTGRES_USER=pleroma \
    -e POSTGRES_PASSWORD=CHANGHEME \
    -e POSTGRES_DB=pleroma \
    -v ./postgres:/var/lib/postgresql/data \
    postgres:12.1-alpine

if [[ $1 == "db-setup" ]]; then
    podman exec -i pleroma-db psql -U pleroma -c "CREATE EXTENSION IF NOT EXISTS citext;"
    exit 0
fi
runvars="pleroma:"
runmode="-d"
if [[ $1 == "build-setup" ]]; then
    podman build -f Dockerfile -t pleroma:$1
    runvars=$runvars$1" mix ecto.migrate"
    runmode="--rm"
elif [[ $1 == "final-build" ]]; then
    podman build -f Dockerfile -t pleroma:run
    runvars=$runvars"run"
fi



podman run $runmode \
    --name pleroma-web \
    --pod pleroma-pod \
    -v ./uploads:/var/lib/pleroma/uploads \
    -v ./static:/var/lib/pleroma/static \
    -v ./config.exs:/etc/pleroma/config.exs:ro \
    -e DOMAIN=example.tld \
    -e INSTANCE_NAME=Pleroma \
    -e ADMIN_EMAIL=admin@example.tld \
    -e NOTIFY_EMAIL=notify@example.tld \
    -e DB_USER=pleroma \
    -e DB_PASS=CHANGEME \
    -e DB_NAME=pleroma \
    -e DB_HOST=localhost \
    -e POSTGRES_HOST=localhost \
    $runvars

if [[ $1 == "build-setup" ]]; then
    podman exec pleroma-web /pleroma/bin/pleroma_ctl config migrate_to_db
fi

if [[ $1 == "gen-keypair" ]]; then
    podman exec pleroma-web mix web_push.gen.keypair
fi
