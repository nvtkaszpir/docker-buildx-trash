#!/bin/bash
set -x
# point to hormes and build
export DOCKER_HOST=ssh://pi@hormes
docker buildx rm hormes || true
docker buildx create --use --name hormes $DOCKER_HOST

docker buildx build --load --progress plain -t donkeycar:dev-arm --platform=linux/arm .
docker buildx build --load --progress plain -t donkeycar:dev-armhf .

