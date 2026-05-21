FROM node:24-trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends git ca-certificates curl less jq gh \
 && rm -rf /var/lib/apt/lists/*

ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

RUN mkdir -p /home/claude-docked && chmod 777 /home/claude-docked

RUN echo 'PS1="claude-docked:\w\$ "' >> /etc/bash.bashrc

ENV RTK_INSTALL_DIR="/bin"
RUN curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh

ENV SHELL=/bin/bash

CMD ["/usr/bin/claude"]