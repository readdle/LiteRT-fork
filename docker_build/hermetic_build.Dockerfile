# Copyright 2025 Google LLC.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#      http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Standard base (Architecture is decided by the build command)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies (Including compatibility libs)
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    git \
    openjdk-17-jdk \
    python3 \
    python3-pip \
    python3-dev \
    python3-setuptools \
    unzip \
    wget \
    zip \
    llvm-18 \
    clang-18 \
    libc++-dev \
    libc++abi-dev \
    libncurses6 \
    libtinfo6 \
    && apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# We assume x86_64 because we will force it in the build script.
RUN ln -s /usr/lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5 && \
    ln -s /usr/lib/x86_64-linux-gnu/libtinfo.so.6 /usr/lib/x86_64-linux-gnu/libtinfo.so.5

# Install Bazelisk (Force x86_64 version)
RUN wget https://github.com/bazelbuild/bazelisk/releases/download/v1.18.0/bazelisk-linux-amd64 -O bazelisk && \
    chmod +x bazelisk && \
    mv bazelisk /usr/local/bin/bazel && \
    echo "export USE_BAZEL_VERSION=7.4.1" >> /etc/bash.bashrc

# Set up Android SDK and NDK
ENV ANDROID_DEV_HOME=/android
RUN mkdir -p ${ANDROID_DEV_HOME}
RUN mkdir -p /root/.android

# Install Android SDK
ENV ANDROID_SDK_FILENAME=commandlinetools-linux-13114758_latest.zip
ENV ANDROID_SDK_URL=https://dl.google.com/android/repository/${ANDROID_SDK_FILENAME}
ENV ANDROID_API_LEVEL=34
ENV ANDROID_SDK_API_LEVEL=34
ENV ANDROID_BUILD_TOOLS_VERSION=34.0.0
ENV ANDROID_SDK_HOME=${ANDROID_DEV_HOME}/sdk
RUN mkdir -p ${ANDROID_SDK_HOME}/cmdline-tools
ENV PATH=${PATH}:${ANDROID_SDK_HOME}/cmdline-tools/latest/bin:${ANDROID_SDK_HOME}/platform-tools

RUN cd ${ANDROID_DEV_HOME} && \
    wget -q ${ANDROID_SDK_URL} && \
    unzip ${ANDROID_SDK_FILENAME} -d /tmp && \
    mv /tmp/cmdline-tools ${ANDROID_SDK_HOME}/cmdline-tools/latest && \
    rm ${ANDROID_SDK_FILENAME}

# Install Android NDK r25c (Linux x86_64)
ENV ANDROID_NDK_FILENAME=android-ndk-r25c-linux.zip
ENV ANDROID_NDK_URL=https://dl.google.com/android/repository/${ANDROID_NDK_FILENAME}
ENV ANDROID_NDK_HOME=${ANDROID_DEV_HOME}/ndk
ENV PATH=${PATH}:${ANDROID_NDK_HOME}

RUN cd ${ANDROID_DEV_HOME} && \
    wget -q ${ANDROID_NDK_URL} && \
    unzip ${ANDROID_NDK_FILENAME} -d ${ANDROID_DEV_HOME} && \
    rm ${ANDROID_NDK_FILENAME} && \
    bash -c "ln -s ${ANDROID_DEV_HOME}/android-ndk-r25c ${ANDROID_NDK_HOME}"

# Create directories
RUN mkdir -p ${ANDROID_SDK_HOME}/build-tools
RUN mkdir -p ${ANDROID_SDK_HOME}/platforms
RUN mkdir -p ${ANDROID_SDK_HOME}/platform-tools
RUN chmod -R go=u ${ANDROID_DEV_HOME}

# Python setup
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --break-system-packages --require-hashes -r /tmp/requirements.txt

ENV PYTHON_BIN_PATH=/usr/bin/python3
ENV PYTHON_LIB_PATH=/usr/lib/python3/dist-packages
ENV HERMETIC_PYTHON_VERSION=3.12
ENV TF_NEED_CUDA=0
ENV TF_NEED_ROCM=0
ENV TF_DOWNLOAD_CLANG=0
ENV TF_SET_ANDROID_WORKSPACE=1
ENV TF_CONFIGURE_IOS=0
ENV USE_BAZEL_VERSION=7.4.1
ENV CLANG_COMPILER_PATH=/usr/lib/llvm-18/bin/clang
ENV TF_NEED_CLANG=1
ENV ANDROID_NDK_VERSION=25

# Install SDK components
RUN echo y | ${ANDROID_SDK_HOME}/cmdline-tools/latest/bin/sdkmanager --sdk_root=${ANDROID_SDK_HOME} "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" "platforms;android-${ANDROID_SDK_API_LEVEL}" "platform-tools"

WORKDIR /litert_build

# Entrypoint
RUN echo '#!/bin/bash\n\
git config --global --add safe.directory /litert_build\n\
git config --global --add safe.directory /litert_build/third_party/tensorflow\n\
/litert_build/configure --workspace=/litert_build\n\
echo "Configuration complete."\n\
exec "$@"\n\
' > /entrypoint.sh && chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

# Build Wrapper
RUN echo '#!/bin/bash\n\
set -euo pipefail\n\
./docker_build/verify_android_env.sh\n\
mkdir -p /tmp/bazel_cache\n\
bazel --output_user_root=/tmp/bazel_cache build -c opt //litert/samples/model-api:litert_emb_model_so --config=android_arm64\n\
\n\
echo "Copying artifacts to host..."\n\
# Bazel usually places output in bazel-bin/<package_path>\n\
cp -f bazel-bin/litert/samples/model-api/libLitertEmbModel.so /litert_build/\n\
echo "Artifacts available in the project root."\n\
' > /run_build.sh && chmod +x /run_build.sh

CMD ["/run_build.sh"]
#bazel --output_user_root=/tmp/bazel_cache build -c opt //litert/samples/model-api:litert_emb_model_so --config=android_arm64\n\
#bazel --output_user_root=/tmp/bazel_cache build -c opt //litert/samples/semantic_similarity:semantic_similarity --config=android_arm64\n\