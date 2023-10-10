#!/bin/bash

# Remove Directory (if it exists)
rm -rf cks-setup-scripts

# Create Directory
mkdir cks-setup-scripts

CONTENT=$(curl -s https://api.github.com/repos/virtru/cks-setup-script/releases/latest)

URL=$(echo "$CONTENT" | grep "tarball_url*" | cut -d : -f 2,3 | tr -d \" | tr -d ,)

wget $URL -qO - | tar -xvzf - -C cks-setup-scripts
mv cks-setup-scripts/virtru-cks-setup-script*/{VERSION,*.sh} cks-setup-scripts
rm -rf cks-setup-scripts/virtru-cks-setup-script*
