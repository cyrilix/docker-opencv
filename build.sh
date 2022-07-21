#! /bin/bash

OPENCV_VERSION=4.6.0

containerSrcName=opencv-src
containerBuildstageBuilderName=opencv-buildstage-builder
containerBuildstageName=opencv-buildstage
containerRuntimeName=opencv-runtime
IMAGE_SRC_NAME=opencv-src:${OPENCV_VERSION}
IMAGE_BUILDSTAGE_BUILDER_NAME=opencv-buildstage-builder:${OPENCV_VERSION}
MANIFEST_BUILDSTAGE=opencv-buildstage:${OPENCV_VERSION}
MANIFEST_RUNTIME=opencv-runtime:${OPENCV_VERSION}

BASE_IMAGE=docker.io/library/debian:stable-slim
BASE_IMAGE_BUILDSTAGE=docker.io/library/debian:stable-slim
BASE_IMAGE_RUNTIME=docker.io/library/debian:stable-slim

build_src_image() {
  buildah --name "$containerSrcName" from alpine
  buildah run "$containerSrcName" mkdir /tmp/opencv
  buildah config --workingdir /tmp/opencv "$containerSrcName"
  buildah run "$containerSrcName" wget -O opencv.zip https://github.com/opencv/opencv/archive/$OPENCV_VERSION.zip
  buildah run "$containerSrcName" unzip opencv.zip
  buildah run "$containerSrcName" wget -O opencv_contrib.zip https://github.com/opencv/opencv_contrib/archive/$OPENCV_VERSION.zip
  buildah run "$containerSrcName" unzip opencv_contrib.zip
  buildah run "$containerSrcName" mkdir /tmp/opencv/opencv-${OPENCV_VERSION}/build

  buildah commit --rm "${containerSrcName}" "${IMAGE_SRC_NAME}"
}

# Build opencv binary for any os/arch
build_opencv_buildstage_builder() {
  ARCH=$1
  PKG_LIBDIR=$2
  TOOLCHAIN=$3

  if [ "${ARCH}" == "armhf" ]
  then
     EXTRA_FLAGS="-D ENABLE_VFPV3=ON"
  else
     EXTRA_FLAGS=""
  fi

  if [ "${ARCH}" == "arm64" ] || [ "${ARCH}" == "armhf" ]
  then
    #EXTRA_FLAGS="-D ENABLE_VFPV3=ON  -D ENABLE_NEON=ON -D WITH_TBB=ON -D BUILD_TBB=ON -D CMAKE_SHARED_LINKER_FLAGS=-latomic"
    EXTRA_FLAGS="${EXTRA_FLAGS} -D ENABLE_NEON=ON -D WITH_TBB=ON -D BUILD_TBB=ON -D CMAKE_SHARED_LINKER_FLAGS=-latomic"
    EXTRA_FLAGS="-D CMAKE_TOOLCHAIN_FILE=../platforms/linux/${TOOLCHAIN} ${EXTRA_FLAGS}"
  else
    EXTRA_FLAGS=""
  fi

  local containerName="${containerBuildstageBuilderName}-${ARCH}"

  buildah --name "$containerName" --arch amd64 from $BASE_IMAGE
  buildah run "$containerName" mkdir -p /opt/opencv/$ARCH

  buildah run "$containerName" dpkg --add-architecture ${ARCH}

  buildah run "$containerName" apt-get update
  buildah run "$containerName" apt-get install -y \
         crossbuild-essential-${ARCH} \
         ca-certificates \
         build-essential \
         git \
         make \
         cmake \
         libjpeg62-turbo:${ARCH} \
         libpng16-16:${ARCH} \
         libwebp6:${ARCH} \
         libwebp-dev:${ARCH} \
         libtiff5:${ARCH} \
         libavc1394-0:${ARCH} \
         libavc1394-dev:${ARCH} \
         libopenblas0:${ARCH} \
         libopenblas-dev:${ARCH} \
         liblapack-dev:${ARCH} \
         liblapack3:${ARCH} \
         libatlas3-base:${ARCH} \
         libatlas-base-dev:${ARCH} \
         libgphoto2-6:${ARCH} \
         libgphoto2-dev:${ARCH} \
         libgstreamer1.0-0:${ARCH} \
         libgstreamer1.0-dev:${ARCH} \
         libopenjp2-7:${ARCH} \
         libopenjp2-7-dev:${ARCH} \
         libglib2.0-0:${ARCH} \
         libglib2.0-dev:${ARCH} \
         libtiff-dev:${ARCH} zlib1g-dev:${ARCH} \
         libjpeg-dev:${ARCH} libpng-dev:${ARCH} \
         libavcodec-dev:${ARCH} libavformat-dev:${ARCH} libswscale-dev:${ARCH} libv4l-dev:${ARCH} \
         libxvidcore-dev:${ARCH} libx264-dev:${ARCH} \
         cmake pkg-config\
         libeigen3-dev:${ARCH} \
         eigensoft:${ARCH}

  buildah config --workingdir /src "$containerName"
  buildah copy --from localhost/${IMAGE_SRC_NAME} "$containerName"  /tmp/opencv /src/opencv/


  buildah config --workingdir /src/opencv/opencv-${OPENCV_VERSION}/build "${containerName}"

  buildah run \
    --env PKG_CONFIG_PATH="${PKG_LIBDIR}" \
    --env PKG_CONFIG_LIBDIR="${PKG_LIBDIR}" \
   "$containerName" \
    cmake \
    -D CMAKE_BUILD_TYPE=RELEASE \
    -D CMAKE_INSTALL_PREFIX="/opt/opencv/${ARCH}" \
    -D OPENCV_EXTRA_MODULES_PATH=/src/opencv/opencv_contrib-${OPENCV_VERSION}/modules \
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
    -D BUILD_opencv_wechat_qrcode=OFF \
    ${EXTRA_FLAGS} \
    -D OPENCV_GENERATE_PKGCONFIG=YES ..

    buildah run "$containerName" make -j14
    buildah run "$containerName" make install/strip

    buildah commit --rm "${containerName}" "${IMAGE_BUILDSTAGE_BUILDER_NAME}-${ARCH}"
}

build_opencv_buildstage() {

  #buildah --name "$containerBuildstageName" --os "${OS}" --arch "${ARCH}" ${VARIANT} from debian
  buildah --name "$containerBuildstageName" --os "linux" --arch "amd64" from $BASE_IMAGE

  buildah run "$containerBuildstageName" dpkg --add-architecture armhf
  buildah run "$containerBuildstageName" dpkg --add-architecture arm64

  buildah run "$containerBuildstageName" apt-get update
  buildah run "$containerBuildstageName" apt-get install -y \
         git \
         build-essential \
         crossbuild-essential-arm64 \
         crossbuild-essential-armhf \
         make \
         cmake \
         gcc \
         g++

  for a in "amd64" "arm64" "armhf"
  do


    buildah run "$containerBuildstageName" apt-get install -y \
         libjpeg62-turbo:$a \
         libpng16-16:$a \
         libwebp6:$a \
         libtiff5:$a \
         libavc1394-0:$a \
         libopenblas0:$a \
         liblapack3:$a \
         libatlas3-base:$a \
         libgphoto2-6:$a \
         libgstreamer1.0-0:$a \
         libopenjp2-7:$a \
         libglib2.0-0:$a \
         libavcodec58:$a \
         libavformat58:$a \
         libavutil56:$a \
         libtbb2:$a \
         libswscale5:$a \
         eigensoft:$a

    # OpenCV shared objects from build-stage
    buildah copy --from "localhost/${IMAGE_BUILDSTAGE_BUILDER_NAME}-$a" "${containerBuildstageName}" /opt/opencv/$a /opt/opencv/$a
  done

  buildah commit --rm --manifest "${MANIFEST_BUILDSTAGE}" "${containerBuildstageName}"
}

build_opencv_runtime() {

  local platform=$1

  OS=$(echo "$platform" | cut -f1 -d/) && \
  ARCH=$(echo "$platform" | cut -f2 -d/) && \
  ARM=$(echo "$platform" | cut -f3 -d/ | sed "s/v//" )
  VARIANT="--variant $(echo "${platform}" | cut -f3 -d/  )"
  if [[ -z "$ARM" ]] ;
  then
    VARIANT=""
  fi

  if [[ "${ARCH}" == "arm" ]]
  then
    BINARY_ARCH="armhf"
  else
    BINARY_ARCH="${ARCH}"
  fi


  buildah --name "$containerRuntimeName" --os "${OS}" --arch "${ARCH}" ${VARIANT} from $BASE_IMAGE_RUNTIME

  buildah run "$containerRuntimeName" apt-get update
  buildah run "$containerRuntimeName" apt-get install -y \
         libjpeg62-turbo \
         libpng16-16 \
         libwebp6 \
         libtiff5 \
         libavc1394-0 \
         libopenblas0 \
         liblapack3 \
         libatlas3-base \
         libgphoto2-6 \
         libgstreamer1.0-0 \
         libopenjp2-7 \
         libglib2.0-0 \
         libavcodec58 \
         libavformat58 \
         libavutil56 \
         libtbb2 \
         libswscale5 \
         eigensoft

  buildah copy --from "localhost/${IMAGE_BUILDSTAGE_BUILDER_NAME}-$BINARY_ARCH" "${containerRuntimeName}" /opt/opencv/"$BINARY_ARCH" "/opt/opencv"
  buildah config --env LD_LIBRARY_PATH="/opt/opencv/lib/:/usr/lib" "${containerRuntimeName}"

  buildah commit --rm --manifest "localhost/${MANIFEST_RUNTIME}" "${containerRuntimeName}"
}

build_src_image

build_opencv_buildstage_builder armhf "/usr/lib/arm-linux-gnueabihf/pkgconfig:/usr/lib/pkgconfig" arm-gnueabi.toolchain.cmake
build_opencv_buildstage_builder arm64 "/usr/lib/aarch64-linux-gnu/pkgconfig:/usr/lib/pkgconfig" aarch64-gnu.toolchain.cmake
build_opencv_buildstage_builder amd64 "/usr/lib/pkgconfig"

# Shared library
build_opencv_buildstage
buildah manifest push --rm -f v2s2 --all "${MANIFEST_BUILDSTAGE}" "docker://docker.io/cyrilix/${MANIFEST_BUILDSTAGE}"


# Runtime images

build_opencv_runtime "linux/arm/v7" /opt/opencv/armhf
build_opencv_runtime "linux/arm64" /opt/opencv/arm64
build_opencv_runtime "linux/amd64" /opt/opencv/amd64

buildah manifest push --rm -f v2s2 --all "localhost/${MANIFEST_RUNTIME}" "docker://docker.io/cyrilix/${MANIFEST_RUNTIME}"
