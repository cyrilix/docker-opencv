# docker-opencv
 
![Docker](https://github.com/cyrilix/docker-opencv/workflows/Docker/badge.svg?branch=master)

Base image for opencv

2 images are build:

 * cyrilix/opencv-buildstage: used to compile go code
 * cyrilix/opencv-runtime: used to run executable


## Build images
 
Run:
```bash
 docker buildx build . --platform linux/arm/v7,linux/arm64,linux/X86_64 --progress plain --target opencv-buildstage
 docker buildx build . --platform linux/arm/v7,linux/arm64,linux/X86_64 --progress plain
```
