FROM golang:1.16-buster as builder

# Up-to-date libgit2 dependencies are only available in
# unstable, as libssh2 in testing/bullseye has been linked
# against gcrypt which causes issues with PKCS* formats.
# Explicitly listing all build dependencies is required because
# they can only be automagically found for AMD64 builds.
# Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
RUN echo "deb http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list \
    && echo "deb-src http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list
RUN set -eux; \
    apt-get update \
    && apt-get install -y \
        libgit2-dev/unstable \
        zlib1g-dev/unstable \
        libssh2-1-dev/unstable \
        libpcre3-dev/unstable \
        git-secret \
    && apt-get clean \
    && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

# copy api submodule
COPY api/ api/

# copy modules manifests
COPY go.mod go.mod
COPY go.sum go.sum

# cache modules
RUN go mod download

# copy source code
COPY main.go main.go
COPY controllers/ controllers/
COPY pkg/ pkg/
COPY internal/ internal/

# build without specifing the arch
RUN CGO_ENABLED=1 go build -o source-controller main.go

FROM debian:buster-slim as controller

# link repo to the GitHub Container Registry image
LABEL org.opencontainers.image.source="https://github.com/fluxcd/source-controller"

# Up-to-date libgit2 dependencies are only available in
# unstable, as libssh2 in testing/bullseye has been linked
# against gcrypt which causes issues with PKCS* formats.
# Ref: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=668271
RUN echo "deb http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list \
    && echo "deb-src http://deb.debian.org/debian unstable main" >> /etc/apt/sources.list
RUN set -eux; \
    apt-get update \
    && apt-get install -y \
        ca-certificates \
        libgit2-1.1 \
    && apt-get clean \
    && apt-get autoremove --purge -y \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /workspace/source-controller /usr/local/bin/

RUN groupadd controller && \
    useradd --gid controller --shell /bin/sh --create-home controller

USER controller
ENTRYPOINT [ "source-controller" ]
