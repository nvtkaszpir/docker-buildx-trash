#!/bin/bash
set -x
# build on nyx
export DOCKER_HOST=ssh://kaszpir@nyx-m6v
docker buildx rm nyx || true
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes
docker buildx create --use --name nyx $DOCKER_HOST

docker buildx build --load --progress plain -t donkeycar:dev-amd64 --platform=linux/amd64 .

docker buildx build --load --progress plain -t donkeycar:dev-arm32v6 --platform=linux/arm/v6 .
docker buildx build --load --progress plain -t donkeycar:dev-arm32v7 --platform=linux/arm/v7 .
docker buildx build --load --progress plain -t donkeycar:dev-arm --platform=linux/arm .
docker buildx build --load --progress plain -t donkeycar:dev-aarch64 --platform=linux/arm64 .

docker buildx rm nyx || true
