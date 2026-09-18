# The Go toolchain is taken from the official golang image rather than the Debian
# package, because the Debian release pins an older Go. The stage also builds the
# Go-based developer tools, so their module and build caches never reach the final
# image. Only /usr/local/go and the built binaries in /go/bin are copied into the
# final image; the golang stage itself is discarded.
FROM golang:latest AS golang

# The official golang image sets GOPATH=/go, so `go install` places the binaries
# in /go/bin. Versions are resolved at build time so a rebuild always yields the
# current release.
RUN go install golang.org/x/tools/gopls@latest \
 && go install github.com/vektra/mockery/v3@latest \
 && go install mvdan.cc/sh/v3/cmd/shfmt@latest

FROM node:24-trixie-slim

# Disable the interactive download prompt globally in the container
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      bind9-dnsutils \
      bzip2 \
      ca-certificates \
      curl \
      file \
      gh \
      git \
      iproute2 \
      jq \
      less \
      lsof \
      make \
      nano \
      netcat-openbsd \
      patch \
      python3 \
      python3-pip \
      python3-venv \
      rsync \
      shellcheck \
      strace \
      tree \
      unzip \
      wget \
      xz-utils \
      zip \
 && rm -rf /var/lib/apt/lists/*

# glab is installed from the GitLab release .deb rather than the Debian package,
# because the Debian release lags far behind upstream. The version is resolved
# at build time so a rebuild always yields the current release. The .deb is
# verified against the checksums.txt published alongside it.
RUN glab_version="$(curl -fsSL 'https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest' \
      | jq -r '.tag_name | ltrimstr("v")')" \
 && glab_deb="glab_${glab_version}_linux_$(dpkg --print-architecture).deb" \
 && glab_base_url="https://gitlab.com/gitlab-org/cli/-/releases/v${glab_version}/downloads" \
 && cd /tmp \
 && curl -fsSL -o "${glab_deb}" "${glab_base_url}/${glab_deb}" \
 && curl -fsSL "${glab_base_url}/checksums.txt" | grep " ${glab_deb}$" | sha256sum -c - \
 && dpkg -i "${glab_deb}" \
 && rm "${glab_deb}"

# golangci-lint is installed from the GitHub release .deb rather than with
# `go install`, because upstream does not support binaries built from source:
# they carry no version information and may behave differently from the released
# build. The version is resolved at build time and the .deb is verified against
# the checksums file published alongside it. The unauthenticated GitHub API allows
# 60 requests per hour per IP, which is enough for occasional image builds.
RUN golangci_version="$(curl -fsSL 'https://api.github.com/repos/golangci/golangci-lint/releases/latest' \
      | jq -r '.tag_name | ltrimstr("v")')" \
 && golangci_deb="golangci-lint-${golangci_version}-linux-$(dpkg --print-architecture).deb" \
 && golangci_base_url="https://github.com/golangci/golangci-lint/releases/download/v${golangci_version}" \
 && cd /tmp \
 && curl -fsSL -o "${golangci_deb}" "${golangci_base_url}/${golangci_deb}" \
 && curl -fsSL "${golangci_base_url}/golangci-lint-${golangci_version}-checksums.txt" | grep " ${golangci_deb}$" | sha256sum -c - \
 && dpkg -i "${golangci_deb}" \
 && rm "${golangci_deb}"

COPY --from=golang /usr/local/go /usr/local/go
COPY --from=golang /go/bin/ /usr/local/bin/
# /home/claude-docked/go/bin is the default GOPATH bin dir for the runtime HOME,
# so tools installed with `go install` are runnable without extra setup.
ENV PATH="/usr/local/go/bin:/home/claude-docked/go/bin:${PATH}"

RUN npm install -g corepack

ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

RUN mkdir -p /home/claude-docked && chmod 777 /home/claude-docked

RUN echo 'PS1="claude-docked:\w\$ "' >> /etc/bash.bashrc

ENV RTK_INSTALL_DIR="/bin"
RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

ENV SHELL=/bin/bash

CMD ["/usr/bin/claude"]