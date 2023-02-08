#!/bin/bash

# Remove Directory (if it exists)
rm -rf cks-setup-scripts

# Create Directory
mkdir cks-setup-scripts

CONTENT=$(curl -s https://raw.githubusercontent.com/virtru-corp/cks-setup-script/main/download.sh)

URL=$(echo "$CONTENT" | grep "tarball_url*" | cut -d : -f 2,3 | tr -d \" | tr -d ,)
VERSION=$(echo "$CONTENT" | grep "tag_name*" | cut -d : -f 2,3 | tr -d \" | tr -d , | sed 's/ //g')

wget $URL -qO - | tar -xf - -C cks-setup-scripts
cp cks-setup-scripts/virtru-corp-cks-setup-script*/setup-cks-"$VERSION".sh setup-cks-latest.sh
cp cks-setup-scripts/virtru-corp-cks-setup-script*/setup-cks-hsm-"$VERSION".sh setup-cks-hsm-latest.sh
mv cks-setup-scripts/virtru-corp-cks-setup-script*/*.sh cks-setup-scripts
rm -rf cks-setup-scripts/virtru-corp-cks-setup-script*
