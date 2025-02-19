#!/usr/bin/env bash
set -euxo pipefail
#         CONFIG_FILE: ${{ inputs.config-file }}
DEFAULT_CONFIG_FILE=./image-builder-iso.config.toml
CONFIG_FILE="${CONFIG_FILE:-${DEFAULT_CONFIG_FILE}}"
#         IMAGE: ${{ inputs.image }}
IMAGE="${IMAGE:-$1}"
#         BOOTC_IMAGE_BUILDER_IMAGE: ${{ inputs.bootc-image-builder-image }}
DEFAULT_BOOTC_IMAGE_BUILDER_IMAGE="quay.io/centos-bootc/bootc-image-builder:latest"
BOOTC_IMAGE_BUILDER_IMAGE="${BOOTC_IMAGE_BUILDER_IMAGE:-${DEFAULT_BOOTC_IMAGE_BUILDER_IMAGE}}"
#         USE_LIBREPO: ${{ inputs.use-librepo }}
DEFAULT_USE_LIBREPO=true
USE_LIBREPO="${USE_LIBREPO:-${DEFAULT_USE_LIBREPO}}"
GITHUB_OUTPUT="${GITHUB_OUTPUT:-/tmp/output}"
USE_SUDO="${USE_SUDO:-true}"

function sudo {
  if [[ "$USE_SUDO" == "true" ]]; then
    command sudo "$@"
  else
    "$@"
  fi
}

#       run: |
        DESIRED_UID=$(id -u)
        DESIRED_GID=$(id -g)

        CONFIG_FILE_EXTENSION="${CONFIG_FILE##*.}"
        mkdir -p ./output

        if [[ "$USE_LIBREPO" == "true" ]]; then
          USE_LIBREPO_FLAG="--use-librepo=True"
        else
          USE_LIBREPO_FLAG=""
        fi

        sudo podman run \
          --rm \
          --privileged \
          --pull=newer \
          --security-opt label=type:unconfined_t \
          -v $CONFIG_FILE:/config.$CONFIG_FILE_EXTENSION:ro \
          -v ./output:/output \
          -v /var/lib/containers/storage:/var/lib/containers/storage \
          $BOOTC_IMAGE_BUILDER_IMAGE \
          --type iso \
          --local \
          --chown $DESIRED_UID:$DESIRED_GID \
          $USE_LIBREPO_FLAG \
          $IMAGE

          ISO_PATH=$(ls ./output/bootiso/*.iso)

          # Create a checksum of the output file, stored in the same directory
          CHECKSUM=$(sha256sum $ISO_PATH | awk '{print $1}')
          CHECKSUM_PATH=${ISO_PATH}-CHECKSUM
          echo $CHECKSUM > ${CHECKSUM_PATH}

          # Get the parent directory of the ISO
          OUTPUT_DIRECTORY=$(dirname $ISO_PATH)

          echo "OUTPUT_DIRECTORY=$OUTPUT_DIRECTORY" >> $GITHUB_OUTPUT
          echo "CHECKSUM=$CHECKSUM" >> $GITHUB_OUTPUT
          echo "CHECKSUM_PATH=$CHECKSUM_PATH" >> $GITHUB_OUTPUT
          echo "ISO_PATH=$ISO_PATH" >> $GITHUB_OUTPUT
