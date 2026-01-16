FROM debian:testing-slim

MAINTAINER krisek11

ARG TARGETARCH
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Europe/Budapest

RUN apt-get update && apt-get install -y \
    rsync fish iproute2 netcat-openbsd vim tmux curl \
    bind9-dnsutils socat tcpdump tshark iputils-tracepath \
    inetutils-traceroute git awscli jq \
    mariadb-client postgresql-client \
    ca-certificates gnupg \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /

# -------- Architecture mapping --------
RUN case "${TARGETARCH}" in \
      amd64)  export ARCH=amd64  GH_ARCH=amd64  HELM_ARCH=amd64  MONGO_ARCH=x64 ;; \
      arm64)  export ARCH=arm64  GH_ARCH=arm64  HELM_ARCH=arm64  MONGO_ARCH=arm64 ;; \
      *) echo "Unsupported architecture: ${TARGETARCH}" && exit 1 ;; \
    esac && \
    echo "ARCH=${ARCH} GH_ARCH=${GH_ARCH} HELM_ARCH=${HELM_ARCH} MONGO_ARCH=${MONGO_ARCH}" > /arch.env

# -------- kubectl --------
RUN . /arch.env && \
    curl -LO "https://dl.k8s.io/release/$(curl -Ls https://dl.k8s.io/release/stable.txt)/bin/linux/${ARCH}/kubectl" && \
    install -m 0755 kubectl /usr/bin/kubectl && rm kubectl

# -------- GitHub CLI --------
RUN . /arch.env && \
    latest=$(curl -s https://api.github.com/repos/cli/cli/releases/latest | jq -r '.tag_name' | sed 's/v//') && \
    curl -L "https://github.com/cli/cli/releases/download/v${latest}/gh_${latest}_linux_${GH_ARCH}.tar.gz" \
      -o gh.tar.gz && \
    tar zxf gh.tar.gz && \
    mv gh_${latest}_linux_${GH_ARCH}/bin/gh /usr/bin/gh && \
    chmod 755 /usr/bin/gh && \
    rm -rf gh*

# -------- Helm --------
RUN . /arch.env && \
    latest=$(curl -s https://api.github.com/repos/helm/helm/releases/latest | jq -r '.tag_name' | sed 's/v//') && \
    curl -L "https://get.helm.sh/helm-v${latest}-linux-${HELM_ARCH}.tar.gz" \
      -o helm.tar.gz && \
    tar zxf helm.tar.gz && \
    mv linux-${HELM_ARCH}/helm /usr/bin/helm && \
    chmod 755 /usr/bin/helm && \
    rm -rf helm.tar.gz linux-${HELM_ARCH}

# -------- mongosh --------
RUN . /arch.env && \
    MONGO_VERSION=2.3.3 && \
    curl -L "https://downloads.mongodb.com/compass/mongosh-${MONGO_VERSION}-linux-${MONGO_ARCH}.tgz" \
      -o mongosh.tgz && \
    tar zxf mongosh.tgz && \
    cp mongosh-${MONGO_VERSION}-linux-${MONGO_ARCH}/bin/* /usr/bin && \
    rm -rf mongosh*

# -------- kubent --------
ENV TERM=screen
RUN sh -c "$(curl -sSL https://git.io/install-kubent)"

# -------- User --------
RUN groupadd -g 1000 swakc && \
    useradd -u 1000 -g 1000 -ms /bin/bash swakc

USER swakc

# -------- uv / Python --------
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN /home/swakc/.local/bin/uv venv --python 3.13 /home/swakc/uv

CMD ["tmux"]
