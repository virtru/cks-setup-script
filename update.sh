#!/bin/bash

read -p "Enter CKS Version: " CKS_VERSION

# Verify that the version of CKS exists in Docker
STATUS=$(curl -sI https://hub.docker.com/v2/namespaces/virtru/repositories/cks/tags/"v$CKS_VERSION" | head -n 1|cut -d$' ' -f2)

if [ $STATUS -ne 200 ]; then
  echo "Invalid CKS Version"
fi

read -p "Enter the CKS Working Directory: " WORKING_DIR

if ! [ -d "$WORKING_DIR" ]; then
  echo "$WORKING_DIR does not exist. Have you ran the CKS setup script?"
  exit
fi

KEY_PROVIDER_TYPE=$(cat "$WORKING_DIR"/env/cks.env | grep KEY_PROVIDER_TYPE | cut -d "=" -f2)

if [ "$KEY_PROVIDER_TYPE" = "hsm" ]; then
  echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt virtru/cks:v"$CKS_VERSION" serve" > "$WORKING_DIR/run.sh"
else
  echo "docker run --name Virtru_CKS --interactive --tty --detach --env-file "$WORKING_DIR"/env/cks.env -p 443:$PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl virtru/cks:v"$CKS_VERSION" serve" > ./run.sh
fi
