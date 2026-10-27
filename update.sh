#!/bin/bash

RED="\033[1;31m"
BOLD="\033[1m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"
RESET="\033[0m"
CLEAR="\033c"

# Defaults
PORT=9000
KEY_PROVIDER_PATH="/app/keys"
JWT_AUTH_ISSUER="https://api.virtru.com"

envVariableNotSet () {
  VARIABLE=$1
  LINE="$(awk "/^${1}=/{ print NR; exit }" "$WORKING_DIR"/env/cks.env)"

  if [ -z "$LINE" ]; then
    return 0
  else
    return 1
  fi
}

updateEnvVariable () {
  VARIABLE=$1
  VALUE=$2
  LINE="$(awk "/^${1}=/{ print NR; exit }" "$WORKING_DIR"/env/cks.env)"

  if [ -z "$LINE" ]; then
    echo "$VARIABLE=$VALUE" >> "$WORKING_DIR"/env/cks.env
  else
    LINE="$LINE"s
    sed -i '.bak' "$LINE|.*|$VARIABLE=$VALUE|" "$WORKING_DIR"/env/cks.env
  fi
}

# Yes or No Prompt
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

# Verify that the version of CKS exists in Docker
STATUS=$(curl -sI https://containers.virtru.com/v2/cks/manifests/"v$CKS_VERSION" | head -n 1 | cut -d$' ' -f2)

if [ $STATUS -ne 200 ]; then
  echo "Invalid CKS Version"
  exit
fi

read -p "Enter the CKS Working Directory: " WORKING_DIR

if ! [ -d "$WORKING_DIR" ]; then
  echo "$WORKING_DIR does not exist. Have you ran the CKS setup script?"
  exit
fi

# Upgrades
if envVariableNotSet "JWT_AUTH_ENABLED"; then
  printf "Virtru supports authentication to your CKS via JWTs.\n"
  printf "This is configured by providing your Virtru Org ID.\n\n"

  if prompt "Do you want to enable auth via JWTs [yes/no]?"; then
    read -p "Enter your Virtru Org ID: " JWT_AUTH_AUDIENCE

    updateEnvVariable "JWT_AUTH_ENABLED" "true"
    updateEnvVariable "JWT_AUTH_ISSUER" "$JWT_AUTH_ISSUER"
    updateEnvVariable "JWT_AUTH_AUDIENCE" "$JWT_AUTH_AUDIENCE"
  fi
fi

KEY_PROVIDER_TYPE=$(cat "$WORKING_DIR"/env/cks.env | grep KEY_PROVIDER_TYPE | cut -d "=" -f2)

DOCKER_IMAGE="containers.virtru.com/cks:v$CKS_VERSION"
CONTAINER_NAME="Virtru_CKS"

if [ "$KEY_PROVIDER_TYPE" = "hsm" ]; then
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
else
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
fi

chmod +x "$WORKING_DIR/run.sh"

printf "\n${GREEN}Configuration updated!${RESET}\n\n"
printf "Docker image: $DOCKER_IMAGE\n\n"

printf "To apply the changes:\n"
printf "  1. Stop the current container: ${BOLD}docker stop $CONTAINER_NAME${RESET}\n"
printf "  2. Remove the old container: ${BOLD}docker rm $CONTAINER_NAME${RESET}\n"
printf "  3. Start the new container: ${BOLD}bash $WORKING_DIR/run.sh${RESET}\n"
printf "  4. Monitor logs: ${BOLD}docker logs -f $CONTAINER_NAME${RESET}\n\n"
