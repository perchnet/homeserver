#!/bin/bash
# shellcheck disable=SC2174 # "-p -m only applies to deepest subdirectory" because /var and /etc already exist

set -ouex pipefail

# See https://github.com/centos-workstation/achillobator/issues/3
mkdir -m 0700 -p /var/roothome
# Fast track https://gitlab.com/fedora/bootc/base-images/-/merge_requests/71
ln -sf /run /var/run
# Required for Logically Bound images, see https://gitlab.com/fedora/bootc/examples/-/tree/main/logically-bound-images/usr/share/containers/systemd
# ln -sr /etc/containers/systemd/*.container /usr/lib/bootc/bound-images.d/

# Packages
packages=(
#   avahi
  cockpit
#   cockpit-machines
#   cockpit-podman
#   cockpit-files
#   libvirt
#   tmux
#   vim
#   firewalld
  jq
)
dnf install -y "${packages[@]}"

# Docker install: https://docs.docker.com/engine/install/centos/#install-using-the-repository
docker_packages=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install -y "${docker_packages[@]}"

# Tailscale
dnf config-manager --add-repo https://pkgs.tailscale.com/stable/centos/9/tailscale.repo
dnf config-manager --set-disabled tailscale-stable
dnf -y --enablerepo tailscale-stable install \
  tailscale

# Komodo
cd /tmp/scripts/komodo
./bootstrap_komodo.sh

# Services

systemctl enable podman.socket
systemctl enable cockpit.socket
systemctl enable rpm-ostreed-automatic.timer
systemctl enable tailscaled.service
systemctl disable auditd.service
systemctl enable docker.service