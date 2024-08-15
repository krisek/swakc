FROM debian:testing-slim

MAINTAINER krisek11

#RUN apt-get update && apt-get upgrade -y && 
RUN apt-get update && DEBIAN_FRONTEND="noninteractive" TZ=Europe/Budapest apt-get install -y  nano fish iproute2 netcat-openbsd vim tmux curl bind9-dnsutils socat tcpdump tshark iputils-tracepath inetutils-traceroute git awscli jq

WORKDIR /

RUN cd /tmp; curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; mv kubectl /usr/bin/kubectl; chmod 755 /usr/bin/kubectl
RUN cd /tmp; latest=$(curl -s "https://api.github.com/repos/cli/cli/releases/latest" | jq -r ". .tag_name" | sed 's/v//'); curl -L https://github.com/cli/cli/releases/download/v${latest}/gh_${latest}_linux_amd64.tar.gz --output gh_linux_amd64.tar.gz; tar zxvf gh_linux_amd64.tar.gz; mv gh_${latest}_linux_amd64/bin/gh /usr/bin/; chmod 755 /usr/bin/gh; rm -Rf gh_${latest}_linux_amd64 gh_${latest}_linux_amd64.tar.gz
RUN cd /tmp; latest=$(curl -s "https://api.github.com/repos/helm/helm/releases/latest" | jq -r ". .tag_name" | sed 's/v//');   curl https://get.helm.sh/helm-v${latest}-linux-amd64.tar.gz --output helm-linux-amd64.tar.gz; tar zxvf helm-linux-amd64.tar.gz; cp linux-amd64/helm /usr/bin; chmod 755 /usr/bin/helm
RUN cd /tmp; curl https://downloads.mongodb.com/compass/mongosh-2.2.15-linux-x64.tgz --output mongosh-2.2.15-linux-x64.tgz; tar zxf mongosh-2.2.15-linux-x64.tgz; cp mongosh-2.2.15-linux-x64/bin/* /usr/bin; rm -Rf mongosh-2.2.15-linux-x64.tgz mongosh-2.2.15-linux-x64
ENV TERM screen
RUN sh -c "$(curl -sSL https://git.io/install-kubent)"

RUN useradd -u 1000 -ms /bin/bash swakc
USER 1000

CMD tmux
