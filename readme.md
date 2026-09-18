# Kloot
Running Claude in a docker container locally on your system, based on https://github.com/trekhleb/claude-pod/tree/main 

## Session communication
Claude Code sessions running in separate kloot containers can discover and message each other (`ListAgents`, `SendMessage`), just like multiple sessions on a bare host.

Claude Code only treats a peer as reachable when it lives in the same PID namespace and its unix socket under `/tmp/cc-socks` is visible. Kloot makes this work by:
* Starting one anchor container named `kloot-pidns` when none is running. Every kloot session joins its PID namespace via `--pid container:kloot-pidns`.
* Mounting a shared named volume `kloot-tmp` at `/tmp` in every session, so the sockets are visible across containers. A named volume is used instead of a bind mount because unix sockets on a macOS bind mount are unreliable under Docker Desktop.
* Sharing `~/.kloot` as the Claude config dir, which holds the `sessions/<pid>.json` registry that sessions use for discovery.

The anchor container is created automatically and removed again by the last session that exits, so it only exists while at least one session is running. If the launcher was killed before it could clean up (for example by closing the terminal), the anchor is reused by the next start, or can be removed by hand with `docker rm -f kloot-pidns`.

Closing one session while another one starts in the same sub-second can remove the anchor between the starter's check and its container creation. The starting session then fails with a Docker error or exits right after start. Running `kloot` again recreates the anchor.

## Included packages
* RTK (https://github.com/rtk-ai/rtk)
* glab, the GitLab CLI, latest release from https://gitlab.com/gitlab-org/cli/-/releases at build time
* Go, latest stable release, copied from the official `golang` Docker image at build time
* gopls, mockery and shfmt, latest release built with `go install` in the `golang` build stage
* golangci-lint, latest release .deb from https://github.com/golangci/golangci-lint/releases at build time
* Python 3 with pip and venv. The container home directory is not persisted, so `pip install --user` is lost when the session ends; create a virtualenv inside the project directory instead
* Utilities: unzip, zip, xz, bzip2, make, patch, file, tree, wget, rsync, iproute2, dig, nc, lsof, strace, shellcheck, nano

## Installation
* Clone the project on your machine
* cd <cloned folder>
* task build
* task install

## Usage
Run `kloot <Claude options>` in your repo folder

## Configuration
Kloot will create its own config folder in your homedir `~/.kloot`, here you can find all Claude config files as usual.

### user credentials configs
The container users `~/.config` is mounted into your own homedir on the host in folder `~/kloot-config` to save credentials and configs specific for the claude agent inside the container.

## Updating
You can update Claude by running `task build` inside the cloned folder. 
