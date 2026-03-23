FROM debian:testing-slim

MAINTAINER krisek11

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

RUN apt-get update && apt-get install -y \
    systemd-standalone-sysusers \
    rsync fish iproute2 netcat-openbsd vim tmux curl \
    bind9-dnsutils socat tcpdump tshark iputils-tracepath \
    inetutils-traceroute git awscli jq \
    mariadb-client postgresql-client \
    ca-certificates gnupg inotify-tools && rm -rf /var/lib/apt/lists/*

WORKDIR /

# -------- Architecture mapping --------
RUN case "${TARGETARCH}" in \
      amd64)  export ARCH=amd64  GH_ARCH=amd64  HELM_ARCH=amd64  MONGO_ARCH=x64 ;; \
      arm64)  export ARCH=arm64  GH_ARCH=arm64  HELM_ARCH=arm64  MONGO_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "ARCH=${ARCH} GH_ARCH=${GH_ARCH} HELM_ARCH=${HELM_ARCH} MONGO_ARCH=${MONGO_ARCH}" > /arch.env

# -------- kubectl --------
ARG TARGETARCH


RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) ARCH=amd64 ;; \
      arm64) ARCH=arm64 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    KVER="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"; \
    curl -fsSL -o /usr/bin/kubectl \
      "https://dl.k8s.io/release/${KVER}/bin/linux/${ARCH}/kubectl"; \
    chmod 755 /usr/bin/kubectl

ARG TARGETARCH

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) GH_ARCH=amd64 ;; \
      arm64) GH_ARCH=arm64 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    GH_VER="$(curl -fsSL https://api.github.com/repos/cli/cli/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//')"; \
    curl -fsSL -o gh.tgz \
      "https://github.com/cli/cli/releases/download/v${GH_VER}/gh_${GH_VER}_linux_${GH_ARCH}.tar.gz"; \
    tar -xzf gh.tgz; \
    install -m 0755 "gh_${GH_VER}_linux_${GH_ARCH}/bin/gh" /usr/bin/gh; \
    rm -rf gh.tgz "gh_${GH_VER}_linux_${GH_ARCH}"

ARG TARGETARCH

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) HELM_ARCH=amd64 ;; \
      arm64) HELM_ARCH=arm64 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    HELM_VER="$(curl -fsSL https://api.github.com/repos/helm/helm/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//')"; \
    curl -fsSL -o helm.tgz \
      "https://get.helm.sh/helm-v${HELM_VER}-linux-${HELM_ARCH}.tar.gz"; \
    tar -xzf helm.tgz; \
    install -m 0755 "linux-${HELM_ARCH}/helm" /usr/bin/helm; \
    rm -rf helm.tgz "linux-${HELM_ARCH}"

ARG TARGETARCH

RUN set -eux; \
    case "${TARGETARCH}" in \
      amd64) MONGO_ARCH=x64 ;; \
      arm64) MONGO_ARCH=arm64 ;; \
      *) echo "Unsupported arch: ${TARGETARCH}" && exit 1 ;; \
    esac; \
    MONGO_VERSION=2.3.3; \
    curl -fsSL -o mongosh.tgz \
      "https://downloads.mongodb.com/compass/mongosh-${MONGO_VERSION}-linux-${MONGO_ARCH}.tgz"; \
    tar -xzf mongosh.tgz; \
    cp "mongosh-${MONGO_VERSION}-linux-${MONGO_ARCH}/bin/"* /usr/bin/; \
    rm -rf mongosh.tgz "mongosh-${MONGO_VERSION}-linux-${MONGO_ARCH}"


# -------- kubent --------
ENV TERM=screen
RUN sh -c "$(curl -sSL https://git.io/install-kubent)"

# -------- User --------
RUN groupadd -g 1000 swakc && \
    useradd -u 1000 -g 1000 -ms /bin/bash swakc

USER swakc

# ------------------------------------------------------------
# krew (kubectl plugin manager) and plugins
# ------------------------------------------------------------
RUN set -eux; \
    cd /tmp; \
    OS=$(uname | tr '[:upper:]' '[:lower:]'); \
    ARCH=$(uname -m); \
    case "$ARCH" in \
        x86_64) ARCH=amd64 ;; \
        aarch64) ARCH=arm64 ;; \
        *) echo "Unsupported arch $ARCH" && exit 1 ;; \
    esac; \
    curl -fsSLO "https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-${OS}_${ARCH}.tar.gz"; \
    tar zxvf "krew-${OS}_${ARCH}.tar.gz"; \
    "./krew-${OS}_${ARCH}" install krew; \
    export KREW_ROOT="/home/swakc/.krew"; \
    export PATH="${KREW_ROOT}/bin:${PATH}"; \
    kubectl krew install view-secret cilium-policy-gen cert-manager node-shell neat whoami; \
    rm -rf /tmp/krew-${OS}_${ARCH}*

ENV KREW_ROOT="/home/swakc/.krew"
ENV PATH="${KREW_ROOT}/bin:${PATH}"

# -------- uv / Python --------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN /home/swakc/.local/bin/uv venv --python 3.13 /home/swakc/uv

CMD ["tmux"]
