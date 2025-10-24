FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    git \
    cmake \
    build-essential \
    libgtk-3-dev \
    libsecret-1-dev \
    protobuf-compiler \
    libprotobuf-dev \
    curl \
    unzip \
    ninja-build \
    clang \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

    RUN git clone https://github.com/flutter/flutter.git /flutter
ENV PATH="/flutter/bin:${PATH}"

RUN useradd -ms /bin/bash builder
RUN chown -R builder:builder /flutter
RUN chown -R builder:builder /home/builder

USER builder

ENV HOME /home/builder
ENV PATH="${HOME}/.cargo/bin:${HOME}/.pub-cache/bin:${PATH}"

RUN flutter precache

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

COPY --chown=builder:builder . /app
WORKDIR /app

RUN git config --global --add safe.directory /flutter

RUN . "${HOME}/.cargo/env" && \
    echo "Starting build process..." && \
    cd rust && cargo fetch --verbose && cd .. && \
    dart pub global activate protoc_plugin 21.1.2 && \
    dart pub global activate fastforge && \
    protoc -Ilib/protos --dart_out=lib/protos lib/protos/*.proto google/protobuf/timestamp.proto && \
    fastforge release --name veil

FROM alpine:3.19 AS artifacts

COPY --from=builder /app/linux/packaging/dist/ /dist