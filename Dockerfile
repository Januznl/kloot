# The Go toolchain is taken from the official golang image rather than the Debian
# package, because the Debian release pins an older Go. Only /usr/local/go is
# copied into the final image; the golang stage itself is discarded.
FROM golang:latest AS golang

FROM node:24-trixie-slim

# Disable the interactive download prompt globally in the container
ENV COREPACK_ENABLE_DOWNLOAD_PROMPT=0

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl less jq gh \
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

COPY --from=golang /usr/local/go /usr/local/go
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