#!/bin/bash

# Resolve to the directory of this script to make path handling robust,
# regardless of the current working directory when invoking the script.
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
SERVICES_DIR=${ROOT_DIR}'/services'
UTILS_DIR=${ROOT_DIR}'/utils'
DOS2UNIX="${UTILS_DIR}/dos2unix.exe"
BASE_DIR=${SERVICES_DIR}'/base'
SUBSCRIPTION_MANAGER_DIR=${SERVICES_DIR}"/subscription_manager"
SUBSCRIPTION_MANAGER_DIR_SRC=${SUBSCRIPTION_MANAGER_DIR}"/src"
SWIM_ADSB_DIR=${SERVICES_DIR}"/swim_adsb"
SWIM_ADSB_DIR_SRC=${SWIM_ADSB_DIR}"/src"
SWIM_EXPLORER_DIR=${SERVICES_DIR}"/swim_explorer"
SWIM_EXPLORER_DIR_SRC=${SWIM_EXPLORER_DIR}"/src"
SWIM_USER_CONFIG_DIR=${SERVICES_DIR}"/swim_user_config"
SWIM_USER_CONFIG_DIR_SRC=${SWIM_USER_CONFIG_DIR}"/src"

# Wrapper to support both "docker compose" (new) and "docker-compose" (legacy)
dc() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
  else
    docker-compose "$@"
  fi
}

# Derive the Compose project name similar to docker-compose defaults.
project_name() {
  if [[ -n "${COMPOSE_PROJECT_NAME:-}" ]]; then
    printf "%s" "${COMPOSE_PROJECT_NAME}"
  else
    # Default: lowercased directory name with spaces to hyphens
    basename "${ROOT_DIR}" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
  fi
}

is_windows() {
  UNAME=$(uname)
  [[ "${UNAME}" != "Linux" ]] && [[ "${UNAME}" != "Darwin" ]]
}

fetch_user_config() {
  if [[ -d ${SWIM_USER_CONFIG_DIR_SRC} ]]
  then
    cd "${SWIM_USER_CONFIG_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q https://github.com/eurocontrol-swim/swim-user-config.git "${SWIM_USER_CONFIG_DIR_SRC}"
  fi
  cd "${ROOT_DIR}" || exit
}

user_config() {
  # check the prompt argument
  if [[ ${1} == '1' ]]
  then
    P='-p'
  else
    P=''
  fi

  echo "SWIM user configuration..."
  echo -e "=========================="

  ENV_FILE="${ROOT_DIR}/swim.env"
  touch "${ENV_FILE}"

  python "${SWIM_USER_CONFIG_DIR_SRC}/swim_user_config/main.py" -c "${SWIM_USER_CONFIG_DIR}/config.json" -o "${ENV_FILE}" ${P}

  if is_windows
  then
    # If dos2unix.exe is not present, attempt to use system 'dos2unix' if available.
    if [[ -x "${DOS2UNIX}" ]]; then
      "${DOS2UNIX}" -q "${ENV_FILE}"
    elif command -v dos2unix >/dev/null 2>&1; then
      dos2unix -q "${ENV_FILE}"
    else
      # Fallback: strip CR characters with sed
      sed -i 's/\r$//' "${ENV_FILE}"
    fi
  fi

  # Export only valid KEY=VALUE lines, ignore empty lines and comments
  while IFS= read -r LINE; do
    case "${LINE}" in
      ''|'#'*) continue;;
      *=*) export "${LINE}";;
    esac
  done < "${ENV_FILE}"

  # Echo what was exported (useful for CI/debug); ignore comments/empty lines
  while IFS= read -r LINE; do
    case "${LINE}" in
      ''|'#'*) continue;;
      *=*) echo "export ${LINE}";;
    esac
  done < "${ENV_FILE}"

  # Keep env file for reuse; uncomment to clean up automatically:
  # rm "${ENV_FILE}"
}

prepare_repos() {
  echo "Preparing Git repositories..."
  echo -e "============================\n"

  echo -n "Preparing subscription-manager..."
  if [[ -d ${SUBSCRIPTION_MANAGER_DIR_SRC} ]]
  then
    cd "${SUBSCRIPTION_MANAGER_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q --depth 1 https://github.com/MulvadT/subscription-manager.git "${SUBSCRIPTION_MANAGER_DIR_SRC}"
  fi
  echo "OK"

  echo -n "Preparing swim-adsb..."
  if [[ -d ${SWIM_ADSB_DIR_SRC} ]]
  then
    cd "${SWIM_ADSB_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q --depth 1 https://github.com/MulvadT/swim-adsb.git "${SWIM_ADSB_DIR_SRC}"
  fi
  echo "OK"

  echo -n "Preparing swim-explorer..."
  if [[ -d ${SWIM_EXPLORER_DIR_SRC} ]]
  then
    cd "${SWIM_EXPLORER_DIR_SRC}" || exit
    git pull -q --rebase origin master
  else
    git clone -q --depth 1 https://github.com/MulvadT/swim-explorer.git "${SWIM_EXPLORER_DIR_SRC}"
  fi
  echo "OK"

  echo -e "\n\n"
  cd "${ROOT_DIR}" || exit
}

data_provision() {
  echo "Data provisioning to Subscription Manager..."
  echo -e "============================================\n"

  dc build db broker

  # Run the provisioner twice by design, with retry logic.
  # First run may fail transiently; don't abort on first failure.
  if ! dc run --rm subscription-manager-provision; then
    echo "First provision run failed, retrying after short delay..."
    sleep 2
  fi
  dc run --rm subscription-manager-provision
  echo ""
}

start_services() {
  echo "Starting up SWIM..."
  echo -e "===================\n"
  dc up -d web-server subscription-manager swim-adsb swim-explorer
  echo ""
}

stop_services_with_clean() {
  echo "Stopping SWIM and removing containers..."
  echo -e "========================================\n"
  dc down
  echo ""
}

stop_services_with_purge() {
  echo "Stopping SWIM and removing containers and volumes..."
  echo -e "====================================================\n"

  # Preferred: let compose purge volumes it created
  dc down -v

  # Additional safety: if anything lingers, remove project-scoped volumes by name/label
  PNAME="$(project_name)"
  # Try by label (Compose v2)
  docker volume ls -q --filter "label=com.docker.compose.project=${PNAME}" | xargs -r docker volume rm
  # Fallback by name prefix
  docker volume ls -q | grep -E "^${PNAME}_" | xargs -r docker volume rm

  echo ""
}

reset_docker_images() {
  echo "Resetting Docker environment..."
  echo -e "===============================\n"

  # Stop containers via compose
  dc down

  # Remove all containers created by this compose project (safe, precise)
  PNAME="$(project_name)"
  echo "Removing containers for project: ${PNAME}..."
  docker ps -a -q --filter "label=com.docker.compose.project=${PNAME}" | xargs -r docker rm -f

  # Remove all volumes associated with the project
  echo "Removing associated volumes..."
  docker volume ls -q --filter "label=com.docker.compose.project=${PNAME}" | xargs -r docker volume rm
  # Fallback by name prefix
  docker volume ls -q | grep -E "^${PNAME}_" | xargs -r docker volume rm

  echo -e "\nReset complete. You can now rebuild and start your services fresh."
}

stop_services() {
  echo "Stopping SWIM..."
  echo -e "================\n"
  dc stop
  echo ""
}

build() {
  echo "Building images..."
  echo -e "==================\n"

  # build the base images upon which the swim services will depend on
  cd "${BASE_DIR}" || exit 1

  docker build --no-cache --force-rm -t swim-base -f Dockerfile .
  docker build --no-cache --force-rm -t swim-base.conda -f Dockerfile.conda .

  # Build the rest of the images via compose
  cd "${ROOT_DIR}" || exit 1
  dc build --force-rm

  echo ""
}

status() {
  # Show project services if compose is available; else fall back to all containers
  if docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1; then
    dc ps
  else
    docker ps
  fi
}

usage() {
  echo -e "Usage: swim.sh [COMMAND] [OPTIONS]\n"
  echo "Commands:"
  echo "    user_config             Generates username/password for all the SWIM related users"
  echo "    user_config --prompt    Prompts for username/password for all the SWIM related users"
  echo "    build                   Clones/updates the necessary git repositories and builds the involved docker images"
  echo "    provision               Provisions the Subscription Manager with initial data (users)"
  echo "    start                   Starts up all the SWIM services"
  echo "    stop                    Stops all the services"
  echo "    stop --clean            Stops all the services and cleans up the containers"
  echo "    stop --purge            Stops all the services and cleans up the containers and the volumes"
  echo "    resetAll                Stops services and removes containers and volumes tied to this project"
  echo "    status                  Displays the status of the running containers"
  echo ""
}

ACTION=${1}

case ${ACTION} in
  build)
    # update the repos if they exist otherwise clone them
    prepare_repos
    # build the images
    build
    ;;
  start)
    start_services
    ;;
  stop)
    if [[ -n ${2} ]]
    then
      EXTRA=${2}

      case ${EXTRA} in
          --clean)
            stop_services_with_clean
            ;;
          --purge)
            stop_services_with_purge
            ;;
          *)
            echo -e "Invalid argument\n"
            usage
            ;;
        esac
    else
      stop_services
    fi
    ;;
  provision)
    data_provision
    ;;
  resetAll)
    reset_docker_images
    ;;
  status)
    status
    ;;
  user_config)
    # update the swim-user-config repository
    fetch_user_config

    if [[ -n ${2} ]]
    then
      EXTRA=${2}

      case ${EXTRA} in
          --prompt)
            user_config 1
            ;;
          *)
            echo -e "Invalid argument\n"
            usage
            ;;
        esac
    else
      user_config 0
    fi
    ;;
  help)
    usage
    ;;
  *)
    echo -e "Invalid action\n"
    usage
    ;;
esac