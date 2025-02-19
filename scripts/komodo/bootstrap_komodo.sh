#!/usr/bin/env bash
# shellcheck disable=SC2174 # "-p -m only applies to deepest subdirectory" because /var and /etc already exist
# Komodo Core & local Periphery server via systemd
# vaguely adapted from https://komo.do/docs/setup/mongo
set -euo pipefail
set -x


################################################################################
### Variables ##################################################################
################################################################################

# Where to download Komodo from
KOMODO_REPO_USER="${KOMODO_REPO_USER:-"moghtech"}" # formerly mbecker20
KOMODO_REPO="${KOMODO_REPO:-"komodo"}"
KOMODO_BRANCH="${KOMODO_BRANCH:-"main"}"
KOMODO_REF="${KOMODO_REF:-"refs/heads/${KOMODO_BRANCH}"}"
KOMODO_DB_KIND="${KOMODO_DB_KIND:-"mongo"}" # or postgres, or sqlite
KOMODO_REPO_URL_BASE="${KOMODO_REPO_URL_BASE:-"https://raw.githubusercontent.com/${KOMODO_REPO_USER}/${KOMODO_REPO}/${KOMODO_REF}"}"
SYSTEM_ARCH="$(uname -m)"
PERIPHERY_VERSION="${PERIPHERY_VERSION:-"latest"}"
PERIPHERY_RELEASE_URL="${KOMODO_RELEASE_URL:-"https://github.com/${KOMODO_REPO_USER}/${KOMODO_REPO}/releases/${PERIPHERY_VERSION}/download/periphery-${SYSTEM_ARCH}"}"

KOMODO_COMPOSE_YAML="${KOMODO_COMPOSE_YAML:-"${KOMODO_REPO_URL_BASE}/compose/${KOMODO_DB_KIND}.compose.yaml"}"

KOMODO_ENV="${KOMODO_ENV:-"${KOMODO_REPO_URL_BASE}/compose/compose.env"}"

KOMODO_CORE_DEFAULT_CONFIG="${KOMODO_CORE_DEFAULT_CONFIG:-"${KOMODO_REPO_URL_BASE}/config/core.config.toml"}"
PERIPHERY_DEFAULT_CONFIG="${PERIPHERY_DEFAULT_CONFIG:-"${KOMODO_REPO_URL_BASE}/config/periphery.config.toml"}"
PERIPHERY_CONFIG_PATH="${PERIPHERY_CONFIG_PATH:-"/etc/komodo/periphery/periphery.config.toml"}"
###

################################################################################
# Komodo default settings & overrides ##########################################
################################################################################
COMPOSE_LOGGING_DRIVER="${COMPOSE_LOGGING_DRIVER:-"journald"}"
KOMODO_FIRST_SERVER="${KOMODO_FIRST_SERVER:-"https://host.docker.internal:8120"}"
KOMODO_TITLE="${KOMODO_TITLE:-"Komodo"}"
KOMODO_HOST="${KOMODO_HOST:-$(hostname -f)}"

# Where to install Komodo
PREFIX="${PREFIX:-""}" # Use this to install to a different directory, or for testing.

# Where to store shared files
KOMODO_SHARE_DIR="${KOMODO_SHARE_DIR:-"${PREFIX}/usr/share/komodo"}"
# Where to store default config
KOMODO_DEFAULT_CONFIG_DIR_BASE="${KOMODO_DEFAULT_CONFIG_DIR_BASE:-"${KOMODO_SHARE_DIR}"}"
KOMODO_DEFAULT_CONFIG_DIR_CORE="${KOMODO_DEFAULT_CONFIG_DIR_CORE:-"${KOMODO_DEFAULT_CONFIG_DIR_BASE}/core"}"
KOMODO_DEFAULT_CONFIG_DIRS_CORE=(
  "${KOMODO_DEFAULT_CONFIG_DIR_CORE}/"
)
KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY="${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY:-"${KOMODO_DEFAULT_CONFIG_DIR_BASE}/periphery"}"
KOMODO_DEFAULT_CONFIG_DIRS_PERIPHERY=(
  "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/"
)

KOMODO_CONFIG_DIR_BASE="${KOMODO_CONFIG_DIR_BASE:-"${PREFIX}/etc/komodo"}"
KOMODO_CONFIG_DIR_CORE="${KOMODO_CONFIG_DIR_CORE:-"${KOMODO_CONFIG_DIR_BASE}/core"}"
KOMODO_CONFIG_DIRS_CORE=(
  "${KOMODO_CONFIG_DIR_CORE}/"
)
KOMODO_CONFIG_DIR_PERIPHERY="${KOMODO_CONFIG_DIR_PERIPHERY:-"${KOMODO_CONFIG_DIR_BASE}/periphery"}"
KOMODO_CONFIG_DIRS_PERIPHERY=(
  "${KOMODO_CONFIG_DIR_PERIPHERY}/"
)

# Where to put tmpfiles.d files
TMPFILES_DIR="${TMPFILES_DIR:-"${PREFIX}/usr/lib/tmpfiles.d"}"

# Where to store data
KOMODO_DATA_DIR_BASE="${KOMODO_DATA_DIR_BASE:-"${PREFIX}/var/lib/komodo"}"
KOMODO_DATA_DIR_CORE="${KOMODO_DATA_DIR_CORE:-"${KOMODO_DATA_DIR_BASE}/core"}"
KOMODO_DATA_DIRS_CORE=(
  "${KOMODO_DATA_DIR_CORE}/"
  "${KOMODO_DATA_DIR_CORE}/syncs"
  "${KOMODO_DATA_DIR_CORE}/repos"
)

KOMODO_DATA_DIR_PERIPHERY="${KOMODO_DATA_DIR_PERIPHERY:-"${KOMODO_DATA_DIR_BASE}/periphery"}"
KOMODO_DATA_DIRS_PERIPHERY=(
  "${KOMODO_DATA_DIR_PERIPHERY}/"
  "${KOMODO_DATA_DIR_PERIPHERY}/repos"
  "${KOMODO_DATA_DIR_PERIPHERY}/stacks"
)

# Where to store secrets
KOMODO_SECRETS_DIR_BASE="${KOMODO_SECRETS_DIR_BASE:-"${PREFIX}/etc/komodo/secrets"}"

KOMODO_SECRETS_DIR_CORE="${KOMODO_SECRETS_DIR_CORE:-"${KOMODO_SECRETS_DIR_BASE}/core"}"
KOMODO_SECRETS_DIRS_CORE=(
  "${KOMODO_SECRETS_DIR_CORE}/"
)

KOMODO_SECRETS_DIR_PERIPHERY="${KOMODO_SECRETS_DIR_PERIPHERY:-"${KOMODO_SECRETS_DIR_BASE}/periphery"}"
KOMODO_SECRETS_DIRS_PERIPHERY=(
  "${KOMODO_SECRETS_DIR_PERIPHERY}/"
)

# Where to cache data
KOMODO_CACHE_DIR_BASE="${KOMODO_CACHE_DIR_BASE:-"${PREFIX}/var/cache/komodo"}"

KOMODO_CACHE_DIR_CORE="${KOMODO_CACHE_DIR_CORE:-"${KOMODO_CACHE_DIR_BASE}/core"}"
KOMODO_CACHE_DIRS_CORE=(
  "${KOMODO_CACHE_DIR_CORE}/"
  "${KOMODO_CACHE_DIR_CORE}/repo-cache"
)

KOMODO_CACHE_DIR_PERIPHERY="${KOMODO_CACHE_DIR_PERIPHERY:-"${KOMODO_CACHE_DIR_BASE}/periphery"}"
KOMODO_CACHE_DIRS_PERIPHERY=(
  # "${KOMODO_CACHE_DIR_PERIPHERY}/"
)

KOMODO_COMPOSE_YAML_FILE="${KOMODO_DEFAULT_CONFIG_DIR_CORE}/compose.yml"
KOMODO_DEFAULT_COMPOSE_YAML_OVERRIDE_FILE="${KOMODO_DEFAULT_CONFIG_DIR_CORE}/compose.override.yml"
KOMODO_COMPOSE_YAML_OVERRIDE_FILE="${KOMODO_COMPOSE_YAML_OVERRIDE_FILE:-"${KOMODO_CONFIG_DIR_CORE}/compose.override.yml"}"

# Services dirs
KOMODO_SERVICES_DIR="${KOMODO_SERVICES_DIR:-"${PREFIX}/etc/systemd/system"}"
INITIALIZE_KOMODO_SERVICE="${INITIALIZE_KOMODO_SERVICE:-"${KOMODO_SERVICES_DIR}/initialize-komodo.service"}"
KOMODO_CORE_SERVICE="${KOMODO_CORE_SERVICE:-"${KOMODO_SERVICES_DIR}/komodo-core-up.service"}"
KOMODO_CORE_LOGS_SERVICE="${KOMODO_CORE_LOGS_SERVICE:-"${KOMODO_SERVICES_DIR}/komodo-core-logs.service"}"
KOMODO_PERIPHERY_SERVICE="${KOMODO_PERIPHERY_SERVICE:-"${KOMODO_SERVICES_DIR}/komodo-periphery.service"}"


# Env files to write
KOMODO_CORE_ENV_FILE="${KOMODO_CORE_ENV_FILE:-"${KOMODO_DEFAULT_CONFIG_DIR_CORE}/core.env"}"
KOMODO_PERIPHERY_ENV_FILE="${KOMODO_PERIPHERY_ENV_FILE:-"${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery.env"}"
INITIALIZE_KOMODO_ENV_FILE="${INITIALIZE_KOMODO_ENV_FILE:-"${KOMODO_CONFIG_DIR_BASE}/initialize-komodo.env"}"

# User & Group
KOMODO_USER="${KOMODO_USER:-"root"}" # TODO: This probably should be a non-root user
KOMODO_GROUP="${KOMODO_GROUP:-"wheel"}" # TODO: This probably should be a non-root user
KOMODO_CHOWN="${KOMODO_CHOWN:-"${KOMODO_USER}:${KOMODO_GROUP}"}"

# Permissions
KOMODO_PERMS_DIR_PRIVATE="${KOMODO_PERMS_DIR_PRIVATE:-"0750"}"
KOMODO_PERMS_DIR_NOTRAVERSE="${KOMODO_PERMS_DIR_NOTRAVERSE:-"0754"}"
KOMODO_PERMS_DIR_PUBLIC="${KOMODO_PERMS_DIR_PUBLIC:-"0755"}"
KOMODO_PERMS_EXECUTABLE="${KOMODO_PERMS_EXECUTABLE:-"0755"}"
KOMODO_PERMS_NORMAL="${KOMODO_PERMS_NORMAL:-"0644"}"

EXIT_FAILURE=1

################################################################################
### Functions ##################################################################
################################################################################

# escape slashes in string
escape_slashes() {
    local str
    str="${1}"
    echo "${str//"/"/"\/"}"
}

## CRUD functions for env files
delete_env_key() {
    local key file
    key="${1}"
    file="${2}"
    echo "DELETE: ${key}  => ${file}"
    sed -i -E "/^${key}=.*/d" "${file}"
}

replace_env_key() {
    local key value file
    key="${1}"
    value="${2}"
    file="${3}"
    old_line="$(grep -E "^${key}=" "${file}")"
    echo "REPLACE: ${key}=\"${value}\"  => ${file}"
    echo "(old) ${old_line}"
    key="$(escape_slashes "${key}")"
    value="$(escape_slashes "${value}")"
    sed -i -E "s/^#?${key}=.*/${key}=${value}/" "${file}"
}

add_env_key() {
    local key value file last_byte
    key="${1}"
    value="${2}"
    file="${3}"
    if [[ ! -f "${file}" ]]; then
      echo "creating ${file}"
        touch "${file}"
    fi
    # if the last byte is not newline, then >> doesn't work.
    # check if the last byte is newline, and if not, add one.
    last_byte="$(tail -c 1 "${file}" | wc -l)"
    if [[ "${last_byte}" -eq 0 ]]; then
      echo "adding newline to ${file}"
        printf '%s\n' '' >>"${file}"
    fi
    echo "ADD: ${key}=\"${value}\"  => ${file}"
    echo "${key}=${value}" >>"${file}"
}

update_env_key() {
    local key value file
    key="${1}"
    value="${2}"
    file="${3}"
    needle="^${key}="
    if grep -q "${needle}" "${file}"; then
        replace_env_key "${key}" "${value}" "${file}"
    else
        add_env_key "${key}" "${value}" "${file}"
    fi
}

fetch_url() {
  local url="${1}"
  curl -L "${url}"
}

# get the latest yq binary from github
setup_yq() {
  local repo arch
  repo="mikefarah/yq"
  arch="${SYSTEM_ARCH}"
  case "${arch}" in
    x86_64)
      arch="amd64"
      ;;
    aarch64)
      arch="arm64"
      ;;
    *)
      echo "Maybe unsupported architecture: ${arch}"
      ;;
  esac
  URL="https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_${arch}"
  fetch_url "${URL}" > /usr/bin/yq
  chmod +x /usr/bin/yq
  chown root:root /usr/bin/yq


}

create_directories() {
  # Create directories
  # Since this is an atomic distro, anything under /var needs to be created by a tmpfiles.d file.
  # This is because directories under /var will not be initialized from the container image.

  # default dirs
  for dir in \
    "${KOMODO_DEFAULT_CONFIG_DIR_BASE}" \
    "${KOMODO_DEFAULT_CONFIG_DIRS_CORE[@]}" \
    "${KOMODO_DEFAULT_CONFIG_DIRS_PERIPHERY[@]}"
  do
    mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${dir}"
    chown -R "${KOMODO_CHOWN}" "${dir}"
  done
}

download_compose_yaml() {
  fetch_url "${KOMODO_COMPOSE_YAML}" | yq 'del(.services.periphery)' > "${KOMODO_COMPOSE_YAML_FILE}" # Remove periphery service, because we're running that natively (via systemd instead of docker{,-compose})
  tee "${KOMODO_DEFAULT_COMPOSE_YAML_OVERRIDE_FILE}" <<EOF
services:
  core:
    logging:
      driver: "${COMPOSE_LOGGING_DRIVER}"
    volumes:
      ## Core cache for repos for latest commit hash / contents
      - "${KOMODO_CACHE_DIR_CORE}/repo-cache:/repo-cache"
      ## Store sync files on server
      - "${KOMODO_DATA_DIR_CORE}/syncs:/syncs"
      ## Optionally mount a custom core.config.toml
      - "${KOMODO_CORE_DEFAULT_CONFIG}:/config/config.toml"
    extra_hosts:
      ## Allows for systemd Periphery connection at
      ## "http://host.docker.internal:8120"
      - host.docker.internal:host-gateway

EOF
}

download_env() {
  fetch_url "${KOMODO_ENV}" > "${KOMODO_DEFAULT_CONFIG_DIR_BASE}/default.env"
}

set_first_server() {
  update_env_key "KOMODO_FIRST_SERVER" "${KOMODO_FIRST_SERVER}" "${KOMODO_DEFAULT_CONFIG_DIR_BASE}/default.env"
}

download_core_default_config() {
  fetch_url "${KOMODO_CORE_DEFAULT_CONFIG}" > "${KOMODO_DEFAULT_CONFIG_DIR_CORE}/core.config.toml"
}


download_periphery_default_config() {
  fetch_url "${PERIPHERY_DEFAULT_CONFIG}" > "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery.config.toml"
}

download_periphery_binary() {
  fetch_url "${PERIPHERY_RELEASE_URL}" > "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${PREFIX}/usr/bin"
  ln -s "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery" "${PREFIX}/usr/bin/periphery"
  # Set permissions
  chmod "${KOMODO_PERMS_EXECUTABLE}" "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery" "${PREFIX}/usr/bin/periphery"
}

create_base_dirs() {
  for dir in \
    "${KOMODO_CONFIG_DIR_BASE}" \
    "${KOMODO_DATA_DIR_BASE}" \
    "${KOMODO_SECRETS_DIR_BASE}" \
    "${KOMODO_CACHE_DIR_BASE}"
  do
    mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${dir}"
    chown -R "${KOMODO_CHOWN}" "${dir}"
  done
}

create_core_config_dirs() {
  for dir in "${KOMODO_CONFIG_DIRS_CORE[@]}" ; do
    mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${dir}"
    chown -R "${KOMODO_CHOWN}" "${dir}"
  done
}

install_default_envs() {
  for env in "${KOMODO_CORE_ENV_FILE}" "${KOMODO_PERIPHERY_ENV_FILE}"; do
    install -vDm "${KOMODO_PERMS_EXECUTABLE}" "${KOMODO_DEFAULT_CONFIG_DIR_BASE}/default.env" "${env}"
  done
}

################################################################################
### Main #######################################################################
################################################################################

setup_yq

create_directories

download_compose_yaml

download_env

set_first_server

download_core_default_config

download_periphery_default_config

download_periphery_binary

create_base_dirs

create_core_config_dirs

# install default envs
for env in "${KOMODO_CORE_ENV_FILE}" "${KOMODO_PERIPHERY_ENV_FILE}"; do
  install -vDm "${KOMODO_PERMS_EXECUTABLE}" "${KOMODO_DEFAULT_CONFIG_DIR_BASE}/default.env" "${env}"
done

# install default compose yaml
#install -vDm "${KOMODO_PERMS_NORMAL}" "${KOMODO_COMPOSE_YAML_FILE}" "${KOMODO_CONFIG_DIR_CORE}/compose.yml"
install -vDm "${KOMODO_PERMS_NORMAL}" "${KOMODO_DEFAULT_COMPOSE_YAML_OVERRIDE_FILE}" "${KOMODO_COMPOSE_YAML_OVERRIDE_FILE}"

# install default core config
install -vDm "${KOMODO_PERMS_NORMAL}" "${KOMODO_DEFAULT_CONFIG_DIR_CORE}/core.config.toml" "${KOMODO_CONFIG_DIR_CORE}/core.config.toml"

# install default periphery config
install -vDm "${KOMODO_PERMS_NORMAL}" "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}/periphery.config.toml" "${KOMODO_CONFIG_DIR_PERIPHERY}/periphery.config.toml"

mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${KOMODO_DATA_DIR_BASE}"

# core data dirs
for dir in "${KOMODO_DATA_DIRS_CORE[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${TMPFILES_DIR}"
  echo > "${TMPFILES_DIR}/komodo-core-data-dirs.conf" "d ${dir} ${KOMODO_PERMS_DIR_PRIVATE} ${KOMODO_USER} ${KOMODO_GROUP} - -"
done

# core cache dirs
for dir in "${KOMODO_CACHE_DIRS_CORE[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${TMPFILES_DIR}"
  echo > "${TMPFILES_DIR}/komodo-core-cache-dirs.conf" "d ${dir} ${KOMODO_PERMS_DIR_PRIVATE} ${KOMODO_USER} ${KOMODO_GROUP} - -"
done

# core secrets dirs
for dir in "${KOMODO_SECRETS_DIRS_CORE[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${TMPFILES_DIR}"
  echo > "${TMPFILES_DIR}/komodo-core-secrets-dirs.conf" "d ${dir} ${KOMODO_PERMS_DIR_PRIVATE} ${KOMODO_USER} ${KOMODO_GROUP} - -"
done

# periphery config dirs
for dir in "${KOMODO_CONFIG_DIRS_PERIPHERY[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
done

# periphery data dirs
for dir in "${KOMODO_DATA_DIRS_PERIPHERY[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${TMPFILES_DIR}"
  echo > "${TMPFILES_DIR}/komodo-periphery-data-dirs.conf" "d ${dir} ${KOMODO_PERMS_DIR_PRIVATE} ${KOMODO_USER} ${KOMODO_GROUP} - -"
done

# periphery cache dirs
for dir in "${KOMODO_CACHE_DIRS_PERIPHERY[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${TMPFILES_DIR}"
  echo > "${TMPFILES_DIR}/komodo-periphery-cache-dirs.conf" "d ${dir} ${KOMODO_PERMS_DIR_PRIVATE} ${KOMODO_USER} ${KOMODO_GROUP} - -"
done

# periphery secrets dirs
for dir in "${KOMODO_SECRETS_DIRS_PERIPHERY[@]}" ; do
  mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${dir}"
  chown -R "${KOMODO_CHOWN}" "${dir}"
done

# shared dir
mkdir -v -p -m "${KOMODO_PERMS_DIR_PUBLIC}" "${KOMODO_SHARE_DIR}"

# Set ownership
chown -R "${KOMODO_CHOWN}" "${KOMODO_DEFAULT_CONFIG_DIR_BASE}" "${KOMODO_CONFIG_DIR_BASE}" "${KOMODO_DATA_DIR_BASE}" "${KOMODO_SECRETS_DIR_BASE}" "${KOMODO_CACHE_DIR_BASE}"

# We SHOULDN'T statically bake these keys into the image,
# so we need to write a script to initialize them on first boot.
# However, if you "need" to statically bake any of this in,
# feel free to edit this script.
cp "files/initialize_komodo.sh" "${KOMODO_SHARE_DIR}/initialize_komodo.sh"
chmod 754 "${KOMODO_SHARE_DIR}/initialize_komodo.sh" # only executable as the owner or group
# Write our dir variables into an env file, which the script will use to know where to write the secrets
touch "${INITIALIZE_KOMODO_ENV_FILE}"
for key in \
  KOMODO_CONFIG_DIR_BASE \
  KOMODO_DATA_DIR_BASE \
  KOMODO_SECRETS_DIR_BASE \
  KOMODO_CACHE_DIR_BASE \
  KOMODO_CONFIG_DIR_CORE \
  KOMODO_DATA_DIR_CORE \
  KOMODO_SECRETS_DIR_CORE \
  KOMODO_CACHE_DIR_CORE \
  KOMODO_CONFIG_DIR_PERIPHERY \
  KOMODO_DATA_DIR_PERIPHERY \
  KOMODO_SECRETS_DIR_PERIPHERY \
  KOMODO_CACHE_DIR_PERIPHERY \
  KOMODO_DEFAULT_CONFIG_DIR_BASE \
  KOMODO_DEFAULT_CONFIG_DIR_CORE \
  KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY \
  KOMODO_CORE_ENV_FILE \
  KOMODO_PERIPHERY_ENV_FILE \
  PERIPHERY_CONFIG_PATH \
  KOMODO_SHARE_DIR \
  KOMODO_USER \
  KOMODO_GROUP \
  KOMODO_COMPOSE_YAML_FILE \
  KOMODO_DEFAULT_COMPOSE_YAML_OVERRIDE_FILE \
  KOMODO_COMPOSE_YAML_OVERRIDE_FILE
do
  value="${!key}"
  update_env_key "${key}" "${value}" "${INITIALIZE_KOMODO_ENV_FILE}"
  update_env_key "${key}" "${value}" "${KOMODO_CORE_ENV_FILE}"
  update_env_key "${key}" "${value}" "${KOMODO_PERIPHERY_ENV_FILE}"
done

mkdir -v -p -m "${KOMODO_PERMS_DIR_PRIVATE}" "${PREFIX}/etc/systemd/system"
cp "files/initialize-komodo.service" "${PREFIX}/etc/systemd/system/"
update_env_key "EnvironmentFile" "${INITIALIZE_KOMODO_ENV_FILE}" "${INITIALIZE_KOMODO_SERVICE}"
update_env_key "ExecStart" "${KOMODO_SHARE_DIR}/initialize_komodo.sh" "${INITIALIZE_KOMODO_SERVICE}"

# Copy the systemd service files
cp "files/komodo-core-up.service" "files/komodo-core-logs.service" "files/komodo-periphery.service" "${PREFIX}/etc/systemd/system/"
update_env_key "EnvironmentFile" "${KOMODO_CORE_ENV_FILE}" "${KOMODO_CORE_SERVICE}"
update_env_key "EnvironmentFile" "${KOMODO_PERIPHERY_ENV_FILE}" "${KOMODO_PERIPHERY_SERVICE}"
update_env_key "WorkingDirectory" "${KOMODO_DEFAULT_CONFIG_DIR_CORE}" "${KOMODO_CORE_SERVICE}"
update_env_key "WorkingDirectory" "${KOMODO_DEFAULT_CONFIG_DIR_PERIPHERY}" "${KOMODO_PERIPHERY_SERVICE}"

# Services
if [[ -z "${PREFIX}" ]] ; then
  systemctl enable "${INITIALIZE_KOMODO_SERVICE}"
  systemctl enable "${KOMODO_CORE_SERVICE}"
  systemctl enable "${KOMODO_CORE_LOGS_SERVICE}"
  systemctl enable "${KOMODO_PERIPHERY_SERVICE}"
fi