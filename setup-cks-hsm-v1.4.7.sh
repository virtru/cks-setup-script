#!/bin/bash

RED="\033[1;31m"
BOLD="\033[1m"
GREEN="\033[1;32m"
NOCOLOR="\033[0m"
RESET="\033[0m"
CLEAR="\033c"

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

# Create Directory (prompt if exists to overwrite)
mkdirCheck () {
 if [ -d "$1" ]; then
  if prompt "Directory \"$1\" already exist! Do you want to replace \"$1\" [yes/no]?"; then
    rm -rf $1
    mkdir -p $1
  fi
 else
  mkdir -p $1
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

docker run -e HSM_IP="$HSM_IP" -e PKCS11_VENDOR="$PKCS11_VENDOR" -e PKCS11_LIB_NAME="$PKCS11_LIB_NAME" -e PKCS11_LIB_PATH="$PKCS11_LIB_PATH" -e PKCS11_SLOT_LBL="$PKCS11_SLOT_LBL" -e PKCS11_KEY_LBL="$PKCS11_KEY_LBL" -e PKCS11_PIN="$PKCS11_PIN" -e KEY_PROVIDER_TYPE="$KEY_PROVIDER_TYPE" -e CRYPTO_OPERATIONS_TYPE="$CRYPTO_OPERATIONS_TYPE" --env-file "$WORKING_DIR"/env/cks.env -p 9000:9000 --mount type=bind,source="$WORKING_DIR"/keys,target=/app/keys --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt cks-test:latest list-keys

if prompt "Did the CKS successfully list the keys? Please enter yes or no."; then
  node update-env-file.js "$WORKING_DIR"/env/cks.env HSM_IP="$HSM_IP" PKCS11_VENDOR="$PKCS11_VENDOR" PKCS11_LIB_NAME="$PKCS11_LIB_NAME" PKCS11_LIB_PATH="$PKCS11_LIB_PATH" PKCS11_SLOT_LBL="$PKCS11_SLOT_LBL" PKCS11_KEY_LBL="$PKCS11_KEY_LBL" PKCS11_PIN="$PKCS11_PIN" KEY_PROVIDER_TYPE="$KEY_PROVIDER_TYPE" CRYPTO_OPERATIONS_TYPE="$CRYPTO_OPERATIONS_TYPE"

  echo "Updating the environment file at $WORKING_DIR/env/cks.env."
  echo "Setup of HSM complete"

  set -o allexport
  source "$WORKING_DIR/env/cks.env"
  set +o allexport

  printf "Please use the following command to run CKS.\n\n"
  
  echo "docker run --env-file "$WORKING_DIR"/env/cks.env -p $PORT:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt cks-test:latest serve"
fi
