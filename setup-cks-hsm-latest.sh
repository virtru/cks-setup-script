#!/bin/bash

SCRIPT_DIR=$( dirname -- "$( readlink -f -- "$0"; )"; )
CKS_VERSION="$(head -1 "$SCRIPT_DIR"/VERSION | sed 's/ //g')"

RED="\033[1;31m"
BOLD="\033[1m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"
RESET="\033[0m"
CLEAR="\033c"

# Defaults
PORT=9000
KEY_PROVIDER_PATH="/app/keys"

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

printf "${CLEAR}${GREEN}********************************************\n            CKS HSM SETUP WIZARD\n********************************************\n${RESET}\n"

read -p "Enter Working Directory (should be the same dir used to setup CKS): " WORKING_DIR

if ! [ -d "$WORKING_DIR" ]; then
  echo "$WORKING_DIR does not exist. Have you ran the CKS setup script?"
  exit
fi

HSM_CONFIG_WORKING_DIR="$WORKING_DIR/hsm-config"

printf "* HSM Transport Configuration
** Using certs and keys sent from HSM vendor for Client SSL
*** Put HSM configuration files in $HSM_CONFIG_WORKING_DIR directory
  - customerCA.crt Client HSM certificate\n"

read -p "Press Enter to continue..."

if ! [ -f "$WORKING_DIR/hsm-config/customerCA.crt" ]; then
  echo "Could not find customerCA.crt in $HSM_CONFIG_WORKING_DIR"
  exit
fi

read -p "Enter the HSM Server IP Address: " HSM_IP
read -p "Enter the HSM Slot Label: " HSM_SLOT_LABEL
read -p "Enter the RSA Keypair Label: " HSM_KEY_LABEL
read -p "Enter the HSM Pin (in the format <CU_user_name>:<password>): " HSM_PIN

# CloudHSM Config
PKCS11_VENDOR=custom
PKCS11_LIB_NAME=CloudHSM
PKCS11_LIB_PATH=/opt/cloudhsm/lib/libcloudhsm_pkcs11.so
PKCS11_SLOT_LBL=$HSM_SLOT_LABEL
PKCS11_KEY_LBL=$HSM_KEY_LABEL
PKCS11_PIN=$HSM_PIN
KEY_PROVIDER_TYPE=hsm
CRYPTO_OPERATIONS_TYPE=hsm

# SoftHSM2 Config (Test Mode)
if [ $CKS_HSM_TEST_MODE = "1" ]; then
  PKCS11_LIB_NAME=SoftHSM2
  PKCS11_LIB_PATH=/usr/lib/softhsm/libsofthsm2.so
fi

docker run -e HSM_IP="$HSM_IP" -e PKCS11_VENDOR="$PKCS11_VENDOR" -e PKCS11_LIB_NAME="$PKCS11_LIB_NAME" -e PKCS11_LIB_PATH="$PKCS11_LIB_PATH" -e PKCS11_SLOT_LBL="$PKCS11_SLOT_LBL" -e PKCS11_KEY_LBL="$PKCS11_KEY_LBL" -e PKCS11_PIN="$PKCS11_PIN" -e KEY_PROVIDER_TYPE="$KEY_PROVIDER_TYPE" -e CRYPTO_OPERATIONS_TYPE="$CRYPTO_OPERATIONS_TYPE" --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt virtru/cks:v"$CKS_VERSION" list-keys

if prompt "Did the CKS successfully list the keys? Please enter yes or no."; then
  echo "Updating the environment file at $WORKING_DIR/env/cks.env."

  updateEnvVariable "HSM_IP" "$HSM_IP"
  updateEnvVariable "PKCS11_VENDOR" "$PKCS11_VENDOR"
  updateEnvVariable "PKCS11_LIB_NAME" "$PKCS11_LIB_NAME"
  updateEnvVariable "PKCS11_LIB_PATH" "$PKCS11_LIB_PATH"
  updateEnvVariable "PKCS11_SLOT_LBL" "$PKCS11_SLOT_LBL"
  updateEnvVariable "PKCS11_KEY_LBL" "$PKCS11_KEY_LBL"
  updateEnvVariable "PKCS11_PIN" "$PKCS11_PIN"
  updateEnvVariable "KEY_PROVIDER_TYPE" "$KEY_PROVIDER_TYPE"
  updateEnvVariable "CRYPTO_OPERATIONS_TYPE" "$CRYPTO_OPERATIONS_TYPE"

  echo "Setup of HSM complete"

  if [ $PKCS11_LIB_NAME = "CloudHSM" ]; then
    echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt containers.virtru.com/cks:v"$CKS_VERSION" serve" > "$WORKING_DIR/run.sh"
  else
    echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl containers.virtru.com/cks:v"$CKS_VERSION" serve" > "$WORKING_DIR/run.sh"
  fi
fi
