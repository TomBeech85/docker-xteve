ARG ALPINE_VERSION=3.18
FROM golang:alpine as builder

ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOPATH=/go
ENV GOBIN=/go/bin

COPY xteve-repo/ /source
WORKDIR /source

# Install Go dependencies
RUN apk add --no-cache git && \
    go get ./... && \
    go build -o /xteve xteve.go

# ==============================
# FFmpeg Build Stage
# ==============================
FROM alpine:${ALPINE_VERSION} as ffmpeg-builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    coreutils \
    nasm \
    yasm \
    pkgconfig \
    linux-headers \
    curl \
    x264-dev \
    x265-dev \
    libvpx-dev \
    libvorbis-dev \
    opus-dev \
    mesa-dev

# Install CUDA/NVENC headers
RUN git clone https://git.videolan.org/git/ffmpeg/nv-codec-headers.git && \
    cd nv-codec-headers && \
    make && make install

# Build FFmpeg with NVENC support
RUN git clone https://git.ffmpeg.org/ffmpeg.git && \
    cd ffmpeg && \
    ./configure \
      --enable-gpl \
      --enable-nonfree \
      --enable-libx264 \
      --enable-libx265 \
      --enable-libvpx \
      --enable-libvorbis \
      --enable-libopus \
      --enable-cuda \
      --enable-cuvid \
      --enable-nvenc && \
    make -j$(nproc) && \
    make install

# ==============================
# Final Stage
# ==============================
FROM alpine:${ALPINE_VERSION}

ARG XTEVE_VERSION
ARG XTEVE_COMMIT_REF
ARG DOCKER_XTEVE_COMMIT_REF
ARG BUILD_TIME
ARG BUILD_CI_URL

LABEL org.label-schema.build-date="${BUILD_TIME}" \
    org.label-schema.vcs-ref="${XTEVE_COMMIT_REF}" \
    org.label-schema.vcs-url="https://github.com/xteve-project/xTeVe-Downloads" \
    org.label-schema.version="${XTEVE_VERSION}" \
    org.label-schema.schema-version="1.0" \
    docker-build.vcs-ref="${DOCKER_XTEVE_COMMIT_REF}" \
    docker-build.vcs-url="https://github.com/whi-tw/docker-xteve" \
    docker-build.ci-url="${BUILD_CI_URL}" \
    maintainer="tom@whi.tw"

# Install runtime dependencies
RUN apk add --no-cache \
    ca-certificates \
    tzdata \
    vlc && \
    update-ca-certificates

# Copy built FFmpeg and xTeVe
COPY --from=builder /xteve /xteve
COPY --from=ffmpeg-builder /usr/local/bin/ffmpeg /usr/local/bin/ffmpeg

WORKDIR /xteve
VOLUME ["/config", "/tmp/xteve"]

EXPOSE 34400
ENTRYPOINT [ "/xteve/xteve" ]
CMD [ "-config", "/config" ]
