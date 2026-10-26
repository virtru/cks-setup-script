#!/bin/bash

RED="\033[1;31m"
BOLD="\033[1m"
GREEN="\033[1;32m"
RESET="\033[0m"
CLEAR="\033c"

# Defaults
JWT_AUTH_ISSUER="https://api.virtru.com"

envVariableNotSet () {
  ! grep -q "^$1=" "$WORKING_DIR"/env/cks.env 2>/dev/null
}

updateEnvVariable () {
  VARIABLE=$1
  VALUE=$2
  LINE="$(awk "/^${1}=/{ print NR; exit }" "$WORKING_DIR"/env/cks.env)"

  if [ -z "$LINE" ]; then
    echo "$VARIABLE=$VALUE" >> "$WORKING_DIR"/env/cks.env
  else
    sed -i '.bak' "${LINE}s|.*|$VARIABLE=$VALUE|" "$WORKING_DIR"/env/cks.env
  fi
}

prompt () {
  while true; do
    read -p "$1 " yn
    case $yn in
      [Yy]* ) return 0;;
      [Nn]* ) return 1;;
      * ) echo "Please answer yes or no.";;
    esac
  done
}

printf "${CLEAR}${GREEN}****************************************\n               UPDATE CKS\n****************************************\n${RESET}\n"

read -p "Enter CKS Version: " CKS_VERSION
CKS_VERSION="${CKS_VERSION#v}"

STATUS=$(curl -sI https://containers.virtru.com/v2/cks/manifests/"v$CKS_VERSION" | head -n 1 | cut -d$' ' -f2)
if [ "$STATUS" -ne 200 ]; then
  printf "${RED}Invalid CKS Version${RESET}\n"
  exit 1
fi

read -p "Enter the CKS Working Directory: " WORKING_DIR
if ! [ -d "$WORKING_DIR" ]; then
  echo "$WORKING_DIR does not exist. Have you run the CKS setup script?"
  exit 1
fi

if envVariableNotSet "JWT_AUTH_ENABLED"; then
  printf "Virtru supports authentication to your CKS via JWTs.\n"
  if prompt "Do you want to enable auth via JWTs [yes/no]?"; then
    read -p "Enter your Virtru Org ID: " JWT_AUTH_AUDIENCE
    updateEnvVariable "JWT_AUTH_ENABLED" "true"
    updateEnvVariable "JWT_AUTH_ISSUER" "$JWT_AUTH_ISSUER"
    updateEnvVariable "JWT_AUTH_AUDIENCE" "$JWT_AUTH_AUDIENCE"
  fi
fi

# Node listens directly on the customer-facing container port.
updateEnvVariable "PORT" "9000"

KEY_PROVIDER_TYPE=$(grep '^KEY_PROVIDER_TYPE=' "$WORKING_DIR"/env/cks.env | cut -d "=" -f2-)
KEY_PROVIDER_PATH=$(grep '^KEY_PROVIDER_PATH=' "$WORKING_DIR"/env/cks.env | cut -d "=" -f2-)
KEY_PROVIDER_PATH="${KEY_PROVIDER_PATH:-/app/keys}"
DOCKER_IMAGE="containers.virtru.com/cks:v$CKS_VERSION"
CONTAINER_NAME="Virtru_CKS"

if [ "$KEY_PROVIDER_TYPE" = "hsm" ]; then
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file \"$WORKING_DIR\"/env/cks.env -p 443:9000 --mount type=bind,source=\"$WORKING_DIR\"/keys,target=\"$KEY_PROVIDER_PATH\" --mount type=bind,source=\"$WORKING_DIR\"/ssl,target=/app/ssl --mount type=bind,source=\"$WORKING_DIR\"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
else
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file \"$WORKING_DIR\"/env/cks.env -p 443:9000 --mount type=bind,source=\"$WORKING_DIR\"/keys,target=\"$KEY_PROVIDER_PATH\" --mount type=bind,source=\"$WORKING_DIR\"/ssl,target=/app/ssl $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
fi

chmod +x "$WORKING_DIR/run.sh"

printf "\n${GREEN}Configuration updated!${RESET}\n\n"
printf "Docker image: %s\n\n" "$DOCKER_IMAGE"
printf "To apply the changes:\n"
printf "  1. Stop the current container: ${BOLD}docker stop $CONTAINER_NAME${RESET}\n"
printf "  2. Remove the old container: ${BOLD}docker rm $CONTAINER_NAME${RESET}\n"
printf "  3. Start the new container: ${BOLD}bash $WORKING_DIR/run.sh${RESET}\n"
printf "  4. Monitor logs: ${BOLD}docker logs -f $CONTAINER_NAME${RESET}\n"
