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

# Detect if KAS is already enabled
KAS_ENABLED=false
if grep -q "KAS_ROOT_KEY" "$WORKING_DIR"/env/cks.env 2>/dev/null; then
  KAS_ENABLED=true
  printf "Detected existing KAS configuration.\n\n"
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

# Offer to enable KAS for CKS-only deployments
if [ "$KAS_ENABLED" = false ]; then
  printf "\n${GREEN}Key Access Service (KAS)${RESET}\n"
  printf "KAS is available for this CKS deployment.\n"
  printf "KAS enables integration with Virtru's Data Security Platform.\n\n"

  if prompt "Do you want to enable KAS [yes/no]?"; then
    # Create backup before migration
    printf "Creating backup of current configuration...\n"
    cp "$WORKING_DIR"/env/cks.env "$WORKING_DIR"/env/cks.env.backup.$(date +%Y%m%d_%H%M%S)
    printf "Backup created.\n\n"

    KAS_ENABLED=true

    # Set KAS configuration (no prompts needed - use standard values)
    KAS_AUTH_ISSUER="https://login.virtru.com/oauth2/default"
    KAS_AUTH_AUDIENCE="https://api.virtru.com"
    PLATFORM_ENDPOINT="http://localhost:8080"
    KAS_NAME="customer-kas"

    # Get CKS FQDN from existing SSL certificate for KAS_URI
    CKS_FQDN=$(find "$WORKING_DIR"/ssl/ -name "*.crt" -not -name "ssl.pem" 2>/dev/null | head -1 | xargs basename -s .crt 2>/dev/null)
    if [ -z "$CKS_FQDN" ]; then
      CKS_FQDN="localhost"
    fi
    KAS_URI="https://${CKS_FQDN}"

    # Optional OAuth credentials
    printf "\n${BOLD}Provisioning Configuration (optional):${RESET}\n"
    read -p "Enter OAuth Client ID for provisioning (leave blank to skip): " OKTA_CLIENT_ID
    read -s -p "Enter OAuth Client Secret for provisioning (leave blank to skip): " OKTA_CLIENT_SECRET
    echo ""
    echo ""

    # Generate KAS_ROOT_KEY
    KAS_ROOT_KEY=$(openssl rand -hex 32)

    # Determine key type from existing keys
    if ls "$WORKING_DIR"/keys/ecc_*.pem 1>/dev/null 2>&1; then
      KEY_TYPE="ECC"
      KEY_ALGORITHM="ec:p256"
      KEY_PUBLIC_FILE="/app/keys/ecc_p256_001.pub"
      KEY_PRIVATE_FILE="/app/keys/ecc_p256_001.pem"
    else
      KEY_TYPE="RSA"
      KEY_ALGORITHM="rsa:2048"
      KEY_PUBLIC_FILE="/app/keys/rsa_001.pub"
      KEY_PRIVATE_FILE="/app/keys/rsa_001.pem"
    fi

    # Get existing Org ID from JWT_AUTH_AUDIENCE
    EXISTING_ORG_ID=$(cat "$WORKING_DIR"/env/cks.env | grep JWT_AUTH_AUDIENCE | cut -d "=" -f2)

    # Add KAS environment variables
    updateEnvVariable "KAS_ROOT_KEY" "$KAS_ROOT_KEY"
    updateEnvVariable "ORG_ID" "$EXISTING_ORG_ID"
    updateEnvVariable "KAS_AUTH_ISSUER" "$KAS_AUTH_ISSUER"
    updateEnvVariable "KAS_AUTH_AUDIENCE" "$KAS_AUTH_AUDIENCE"
    updateEnvVariable "KAS_TOKEN_SCOPE" "api:access:read api:access:write"
    updateEnvVariable "KAS_NAME" "$KAS_NAME"
    updateEnvVariable "KAS_URI" "$KAS_URI"
    updateEnvVariable "PLATFORM_ENDPOINT" "$PLATFORM_ENDPOINT"
    updateEnvVariable "WRAPPING_KEY_ID" "kas-root-key"
    updateEnvVariable "KAS_TRUCTL_BIN" "/usr/local/bin/kas"
    updateEnvVariable "KAS_PROVISIONING_DELAY" "10"
    updateEnvVariable "KAS_RETRY_ATTEMPTS" "8"
    updateEnvVariable "KAS_RETRY_BACKOFF" "2"
    updateEnvVariable "KAS_RETRY_BACKOFF_MAX" "30"

    # KAS Logging
    updateEnvVariable "KAS_LOG_LEVEL" "debug"
    updateEnvVariable "KAS_LOG_TYPE" "text"
    updateEnvVariable "KAS_LOG_OUTPUT" "stdout"

    # Database configuration
    updateEnvVariable "DSP_DB_HOST" "localhost"
    updateEnvVariable "DSP_DB_PORT" "5432"
    updateEnvVariable "DSP_DB_DATABASE" "opentdf"
    updateEnvVariable "DSP_DB_USER" "postgres"
    updateEnvVariable "DSP_DB_PASSWORD" "$(openssl rand -hex 16)"
    updateEnvVariable "DSP_DB_SSLMODE" "prefer"
    updateEnvVariable "DSP_DB_SCHEMA" "dsp"

    # Provisioning credentials
    updateEnvVariable "CLIENT_ID" "$OKTA_CLIENT_ID"
    updateEnvVariable "CLIENT_SECRET" "$OKTA_CLIENT_SECRET"
    updateEnvVariable "KEY_ID" "kas-imported-key"
    updateEnvVariable "KEY_ALGORITHM" "$KEY_ALGORITHM"
    updateEnvVariable "KAS_PUBLIC_KEY_FILE" "$KEY_PUBLIC_FILE"
    updateEnvVariable "KAS_PRIVATE_KEY_FILE" "$KEY_PRIVATE_FILE"

    # CKS always runs on internal port 3000 (Caddy exposes 9000)
    updateEnvVariable "PORT" "3000"
    updateEnvVariable "JWT_AUTH_ISSUER" "$KAS_AUTH_ISSUER"

    printf "\n${GREEN}KAS configuration added successfully.${RESET}\n\n"
  fi
fi

KEY_PROVIDER_TYPE=$(cat "$WORKING_DIR"/env/cks.env | grep KEY_PROVIDER_TYPE | cut -d "=" -f2)

# Generate Docker run command (always uses port 9000 via Caddy, no "serve" arg)
DOCKER_IMAGE="containers.virtru.com/cks:v$CKS_VERSION"
CONTAINER_NAME="Virtru_CKS"
OLD_CONTAINER_NAME="Virtru_CKS"
EXTERNAL_PORT=9000  # Caddy always exposes port 9000

if [ "$KEY_PROVIDER_TYPE" = "hsm" ]; then
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file "$WORKING_DIR"/env/cks.env -p 443:$EXTERNAL_PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl --mount type=bind,source="$WORKING_DIR"/hsm-config/customerCA.crt,target=/opt/cloudhsm/etc/customerCA.crt $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
else
  echo "docker run --name $CONTAINER_NAME --interactive --tty --detach --restart unless-stopped --env-file "$WORKING_DIR"/env/cks.env -p 443:$EXTERNAL_PORT --mount type=bind,source="$WORKING_DIR"/keys,target="$KEY_PROVIDER_PATH" --mount type=bind,source="$WORKING_DIR"/ssl,target=/app/ssl $DOCKER_IMAGE" > "$WORKING_DIR/run.sh"
fi

chmod +x "$WORKING_DIR/run.sh"

# Provide clear instructions based on deployment type
printf "\n${GREEN}Configuration updated!${RESET}\n\n"

if [ "$KAS_ENABLED" = true ]; then
  printf "Deployment type: ${BOLD}CKS with KAS${RESET}\n"
else
  printf "Deployment type: ${BOLD}CKS Only${RESET}\n"
fi
printf "Docker image: $DOCKER_IMAGE\n\n"

printf "To apply the changes:\n"
printf "  1. Stop the current container: ${BOLD}docker stop $CONTAINER_NAME${RESET}\n"
printf "  2. Remove the old container: ${BOLD}docker rm $CONTAINER_NAME${RESET}\n"
printf "  3. Start the new container: ${BOLD}bash $WORKING_DIR/run.sh${RESET}\n"
printf "  4. Monitor logs: ${BOLD}docker logs -f $CONTAINER_NAME${RESET}\n\n"

# Additional KAS provisioning instructions if newly enabled
if [ "$KAS_ENABLED" = true ]; then
  printf "${GREEN}KAS Provisioning:${RESET}\n"
  if [ -z "$OKTA_CLIENT_ID" ] || [ -z "$OKTA_CLIENT_SECRET" ]; then
    printf "  ${RED}! OAuth credentials not configured.${RESET}\n"
    printf "  To enable auto-provisioning, edit $WORKING_DIR/env/cks.env\n"
    printf "  and set CLIENT_ID and CLIENT_SECRET, then restart the container.\n\n"
  else
    printf "  OAuth credentials configured. KAS will auto-provision on startup.\n"
    printf "  Check provisioning status in the logs.\n\n"
  fi
fi
