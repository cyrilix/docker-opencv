FROM alpine:3.10 as opencv-buildstage

ENV OPENCV_VERSION=4.5.3

ENV BUILD="ca-certificates \
         git \
         build-base \
         musl-dev \
         alpine-sdk \
         make \
         gcc \
         g++ \
         libc-dev \
         linux-headers \
         libjpeg-turbo \
         libpng \
         libwebp \
         libwebp-dev \
         tiff \
         libavc1394 \
         jasper-libs \
         openblas \
         libgphoto2 \
         gstreamer \
         gst-plugins-base"

ENV DEV="clang clang-dev cmake pkgconf \
         openblas-dev gstreamer-dev gst-plugins-base-dev \
         libgphoto2-dev libjpeg-turbo-dev libpng-dev \
         tiff-dev jasper-dev libavc1394-dev"


RUN apk update && \
    apk add --no-cache ${BUILD} ${DEV}

RUN mkdir /tmp/opencv && \
    cd /tmp/opencv && \
    wget -O opencv.zip https://github.com/opencv/opencv/archive/${OPENCV_VERSION}.zip && \
    unzip opencv.zip && \
    wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/${OPENCV_VERSION}.zip && \
    unzip opencv_contrib.zip && \
    mkdir /tmp/opencv/opencv-${OPENCV_VERSION}/build && cd /tmp/opencv/opencv-${OPENCV_VERSION}/build && \
    cmake \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX=/usr/local \
    -D OPENCV_EXTRA_MODULES_PATH=/tmp/opencv/opencv_contrib-${OPENCV_VERSION}/modules \
    -D WITH_FFMPEG=YES \
    -D INSTALL_C_EXAMPLES=NO \
    -D INSTALL_PYTHON_EXAMPLES=NO \
    -D BUILD_ANDROID_EXAMPLES=NO \
    -D BUILD_DOCS=NO \
    -D BUILD_TESTS=NO \
    -D BUILD_PERF_TESTS=NO \
    -D BUILD_EXAMPLES=NO \
    -D BUILD_opencv_java=NO \
    -D BUILD_opencv_python=NO \
    -D BUILD_opencv_python2=NO \
    -D BUILD_opencv_python3=NO \
    -D OPENCV_GENERATE_PKGCONFIG=YES .. && \
    make -j4 && \
    make install && \
    cd && rm -rf /tmp/opencv

RUN apk del ${DEV_DEPS} && \
    rm -rf /var/cache/apk/*

RUN mkdir -p /usr/local/lib/pkgconfig /usr/local/lib64/pkgconfig





FROM alpine:3.10 as opencv-runtime

# OpenCV shared objects from build-stage
COPY --from=opencv-buildstage /usr/local/lib /usr/local/lib
COPY --from=opencv-buildstage /usr/local/lib64 /usr/local/lib64
COPY --from=opencv-buildstage /usr/local/lib64/pkgconfig/ /usr/local/lib64/pkgconfig/
COPY --from=opencv-buildstage /usr/local/include/opencv4/opencv2 /usr/local/include/opencv4/opencv2

ENV PKG="libstdc++ \
         ca-certificates \
         libjpeg-turbo \
         libpng \
         libwebp \
         libwebp-dev \
         tiff \
         jasper-libs \
         libavc1394 \
         jasper-libs \
         openblas \
         libgphoto2 \
         gstreamer \
         gst-plugins-base "

RUN apk update && \
    apk upgrade && \
    apk add --no-cache ${PKG} && \
    rm -rf /var/cache/apk/*
