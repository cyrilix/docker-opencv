#! /bin/bash
export DOCKER_CLI_EXPERIMENTAL=enabled

docker buildx build --platform linux/amd64,linux/arm64,linux/arm/7 . -t cyrilix/opencv-buildstage:4.1.2 --target opencv-buildstage --push
docker buildx build --platform linux/amd64,linux/arm64,linux/arm/7 . -t cyrilix/opencv-runtime:4.1.2 --push

