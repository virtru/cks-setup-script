#!/bin/bash

RED="\033[1;31m"
BOLD="\033[1m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"
RESET="\033[0m"
CLEAR="\033c"

CONTENT=$(curl -s https://api.github.com/repos/virtru/cks-setup-script/releases/latest)
LATEST_TAG=$(echo "$CONTENT" | grep "tag_name*" | cut -d : -f 2,3 | tr -d \" | tr -d , | sed 's/ //g')
LATEST_VERSION=$(curl -s https://raw.githubusercontent.com/virtru/cks-setup-script/"$LATEST_TAG"/VERSION)

# Defaults
PORT=9000
KEY_PROVIDER_PATH="/app/keys"

envVariableNotSet () {
  VARIABLE=$1
  LINE="$(awk "/${1}/{ print NR; exit }" "$WORKING_DIR"/env/cks.env)"

  if [ -z "$LINE" ]; then
    return 0
  else
    return 1
  fi
}

updateEnvVariable () {
  VARIABLE=$1
  VALUE=$2
  LINE="$(awk "/${1}/{ print NR; exit }" "$WORKING_DIR"/env/cks.env)"

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

printf "The latest version of CKS is $LATEST_VERSION.\n\n"

read -p "Enter CKS Version: " CKS_VERSION

# Verify that the version of CKS exists in Docker
STATUS=$(curl -sI https://hub.docker.com/v2/namespaces/virtru/repositories/cks/tags/"v$CKS_VERSION" | head -n 1 | cut -d$' ' -f2)

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
    updateEnvVariable "JWT_AUTH_AUDIENCE" "$JWT_AUTH_AUDIENCE"
  fi
fi

KEY_PROVIDER_TYPE=$(cat "$WORKING_DIR"/env/cks.env | grep KEY_PROVIDER_TYPE | cut -d "=" -f2)

if [ "$KEY_PROVIDER_TYPE" = "hsm" ]; then
  echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt virtru/cks:v"$CKS_VERSION" serve" > "$WORKING_DIR/run.sh"
else
  echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl virtru/cks:v"$CKS_VERSION" serve" > ./run.sh
fi

printf "\nUpdated! Run the CKS with bash $WORKING_DIR/run.sh\n"
